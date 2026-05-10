from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago
from datetime import timedelta
import boto3
import joblib
import io
from sklearn.datasets import load_breast_cancer
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report
import json

# Configuration
S3_BUCKET = "tony-mlops-2026"
MODEL_KEY = "models/breast_cancer_model.pkl"
METADATA_KEY = "models/model_metadata.json"

def load_and_split_data(**context):
    """Load breast cancer dataset and split into train/test sets"""
    print("Loading breast cancer dataset...")
    data = load_breast_cancer()
    X, y = data.data, data.target
    
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    
    print(f"Dataset loaded: {X_train.shape[0]} training samples, {X_test.shape[0]} test samples")
    print(f"Features: {X_train.shape[1]}")
    print(f"Classes: {len(set(y))}")
    
    # Push data to XCom for next task
    context['ti'].xcom_push(key='X_train', value=X_train.tolist())
    context['ti'].xcom_push(key='y_train', value=y_train.tolist())
    context['ti'].xcom_push(key='X_test', value=X_test.tolist())
    context['ti'].xcom_push(key='y_test', value=y_test.tolist())
    context['ti'].xcom_push(key='feature_names', value=data.feature_names.tolist())
    context['ti'].xcom_push(key='target_names', value=data.target_names.tolist())

def train_model(**context):
    """Train logistic regression model and save to S3"""
    print("Training logistic regression model...")
    
    # Pull data from XCom
    ti = context['ti']
    X_train = ti.xcom_pull(key='X_train', task_ids='load_and_split_data')
    y_train = ti.xcom_pull(key='y_train', task_ids='load_and_split_data')
    X_test = ti.xcom_pull(key='X_test', task_ids='load_and_split_data')
    y_test = ti.xcom_pull(key='y_test', task_ids='load_and_split_data')
    feature_names = ti.xcom_pull(key='feature_names', task_ids='load_and_split_data')
    target_names = ti.xcom_pull(key='target_names', task_ids='load_and_split_data')
    
    # Train model
    model = LogisticRegression(max_iter=10000, random_state=42)
    model.fit(X_train, y_train)
    
    # Evaluate on test set
    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    
    print(f"Model trained successfully!")
    print(f"Training accuracy: {model.score(X_train, y_train):.4f}")
    print(f"Test accuracy: {accuracy:.4f}")
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred))
    
    # Save model directly to S3 (don't pass through XCom)
    print("Saving model to S3...")
    model_bytes = io.BytesIO()
    joblib.dump(model, model_bytes)
    model_bytes.seek(0)
    
    s3 = boto3.client('s3', region_name='us-east-1')
    s3.upload_fileobj(model_bytes, S3_BUCKET, MODEL_KEY)
    print(f"✅ Model uploaded to s3://{S3_BUCKET}/{MODEL_KEY}")
    
    # Create and upload metadata
    metadata = {
        "model_type": "LogisticRegression",
        "accuracy": accuracy,
        "feature_names": feature_names,
        "target_names": target_names,
        "training_date": context['ds'],
        "n_features": len(feature_names)
    }
    
    s3.put_object(
        Bucket=S3_BUCKET,
        Key=METADATA_KEY,
        Body=json.dumps(metadata, indent=2),
        ContentType='application/json'
    )
    print(f"✅ Metadata uploaded to s3://{S3_BUCKET}/{METADATA_KEY}")
    print(f"Model accuracy: {accuracy:.4f}")

def save_model_to_s3(**context):
    """DEPRECATED - Model is now saved in train_model task"""
    print("✅ Model already saved to S3 in train_model task - nothing to do here")

# Define DAG
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    dag_id='breast_cancer_training',
    default_args=default_args,
    description='Train breast cancer classification model and save to S3',
    schedule_interval=None,  # Manual trigger
    start_date=days_ago(1),
    catchup=False,
    tags=['ml', 'training', 's3'],
) as dag:
    
    load_task = PythonOperator(
        task_id='load_and_split_data',
        python_callable=load_and_split_data,
        provide_context=True,
    )
    
    train_task = PythonOperator(
        task_id='train_model',
        python_callable=train_model,
        provide_context=True,
    )
    
    save_task = PythonOperator(
        task_id='save_model_to_s3',
        python_callable=save_model_to_s3,
        provide_context=True,
    )
    
    load_task >> train_task >> save_task
