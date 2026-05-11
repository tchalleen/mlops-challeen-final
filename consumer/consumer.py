import json
import time
import boto3
import joblib
import io
from datetime import datetime
import os
import sys

S3_BUCKET = os.getenv("S3_BUCKET", "tony-mlops-2026")
MODEL_KEY = os.getenv("MODEL_KEY", "models/breast_cancer_model.pkl")
PREDICTIONS_PREFIX = os.getenv("PREDICTIONS_PREFIX", "predictions")
SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL", "https://sqs.us-east-1.amazonaws.com/576524850000/mlops-tonychalleen-final")
AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
MAX_MESSAGES = int(os.getenv("MAX_MESSAGES", "10"))
VISIBILITY_TIMEOUT = int(os.getenv("VISIBILITY_TIMEOUT", "30"))
WAIT_TIME = int(os.getenv("WAIT_TIME", "20"))

s3 = boto3.client('s3', region_name=AWS_REGION)
sqs = boto3.client('sqs', region_name=AWS_REGION)
model = None

def load_model_from_s3():
    """Load model from S3"""
    global model
    
    print(f"Loading model from s3://{S3_BUCKET}/{MODEL_KEY}...")
    
    try:
        response = s3.get_object(Bucket=S3_BUCKET, Key=MODEL_KEY)
        model_bytes = io.BytesIO(response['Body'].read())
        model = joblib.load(model_bytes)
        print("✅ Model loaded successfully!")
        return True
    except Exception as e:
        print(f"❌ Failed to load model: {e}")
        return False

def perform_inference(features):
    """Run inference on features"""
    if model is None:
        raise Exception("Model not loaded")
    
    import numpy as np
    features_array = np.array(features).reshape(1, -1)
    
    prediction = model.predict(features_array)[0]
    
    try:
        probabilities = model.predict_proba(features_array)[0]
        confidence = float(max(probabilities))
    except:
        confidence = None
    
    return int(prediction), confidence

def save_prediction_to_s3(record_id, prediction, confidence=None, true_label=None):
    """Save prediction to S3"""
    timestamp = datetime.utcnow().isoformat() + "Z"
    
    result = {
        "record_id": record_id,
        "prediction": prediction,
        "timestamp": timestamp
    }
    
    if confidence is not None:
        result["confidence"] = confidence
    
    if true_label is not None:
        result["true_label"] = true_label
    
    key = f"{PREDICTIONS_PREFIX}/{record_id}.json"
    
    try:
        s3.put_object(
            Bucket=S3_BUCKET,
            Key=key,
            Body=json.dumps(result, indent=2),
            ContentType='application/json'
        )
        return True
    except Exception as e:
        print(f"Failed to save prediction to S3: {e}")
        return False

def process_message(message_body):
    """Process SQS message"""
    try:
        record_id = message_body.get("record_id")
        features = message_body.get("features")
        true_label = message_body.get("true_label")
        
        if not record_id or features is None:
            raise ValueError("Message missing required fields: record_id or features")
        
        prediction, confidence = perform_inference(features)
        success = save_prediction_to_s3(record_id, prediction, confidence, true_label)
        
        if success:
            conf_str = f"{confidence:.4f}" if confidence else "N/A"
            print(f"✅ Processed {record_id}: prediction={prediction}, confidence={conf_str}")
            return True
        else:
            print(f"⚠️  Failed to save prediction for {record_id}")
            return False
            
    except Exception as e:
        print(f"❌ Error processing message: {e}")
        return False

def poll_queue():
    """Poll SQS and process messages"""
    print("Starting SQS consumer...")
    print(f"Queue URL: {SQS_QUEUE_URL}")
    print(f"S3 Bucket: {S3_BUCKET}")
    print(f"Predictions will be saved to: s3://{S3_BUCKET}/{PREDICTIONS_PREFIX}/")
    print("-" * 60)
    
    processed_count = 0
    failed_count = 0
    
    while True:
        try:
            response = sqs.receive_message(
                QueueUrl=SQS_QUEUE_URL,
                MaxNumberOfMessages=MAX_MESSAGES,
                VisibilityTimeout=VISIBILITY_TIMEOUT,
                WaitTimeSeconds=WAIT_TIME,
            )
            
            messages = response.get("Messages", [])
            
            if not messages:
                print("No messages in queue, waiting...")
                continue
            
            print(f"\nReceived {len(messages)} message(s)")
            
            for msg in messages:
                receipt_handle = msg["ReceiptHandle"]
                
                try:
                    body = json.loads(msg["Body"])
                    success = process_message(body)
                    
                    if success:
                        sqs.delete_message(
                            QueueUrl=SQS_QUEUE_URL,
                            ReceiptHandle=receipt_handle
                        )
                        processed_count += 1
                    else:
                        failed_count += 1
                        print(f"Message will be retried later")
                        
                except json.JSONDecodeError as e:
                    print(f"Invalid JSON: {e}")
                    sqs.delete_message(
                        QueueUrl=SQS_QUEUE_URL,
                        ReceiptHandle=receipt_handle
                    )
                    failed_count += 1
                    
                except Exception as e:
                    print(f"Error processing message: {e}")
                    failed_count += 1
            
            if processed_count % 10 == 0 and processed_count > 0:
                print(f"\n📊 Stats: Processed={processed_count}, Failed={failed_count}")
                
        except Exception as e:
            print(f"Poll error: {e}")
            time.sleep(5)

def main():
    print("=" * 60)
    print("ML Inference Consumer")
    print("=" * 60)
    
    if not load_model_from_s3():
        print("Failed to load model. Exiting...")
        sys.exit(1)
    
    try:
        poll_queue()
    except KeyboardInterrupt:
        print("\n\nShutting down gracefully...")
        sys.exit(0)

if __name__ == "__main__":
    main()
