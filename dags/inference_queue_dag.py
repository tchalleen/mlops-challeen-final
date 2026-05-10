from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago
from datetime import timedelta
import boto3
import json
from sklearn.datasets import load_breast_cancer
from sklearn.model_selection import train_test_split

# Configuration
SQS_QUEUE_URL = "https://sqs.us-east-1.amazonaws.com/576524850000/mlops-tonychalleen-final"
AWS_REGION = "us-east-1"

def load_test_data(**context):
    """Load breast cancer dataset and extract test set"""
    print("Loading breast cancer dataset for inference...")
    data = load_breast_cancer()
    X, y = data.data, data.target
    
    # Use same split as training (same random_state)
    _, X_test, _, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    
    print(f"Test dataset loaded: {X_test.shape[0]} samples")
    
    # Push to XCom
    context['ti'].xcom_push(key='X_test', value=X_test.tolist())
    context['ti'].xcom_push(key='y_test', value=y_test.tolist())
    context['ti'].xcom_push(key='n_samples', value=X_test.shape[0])

def send_to_sqs(**context):
    """Send test records to SQS queue"""
    print("Sending test records to SQS...")
    
    ti = context['ti']
    X_test = ti.xcom_pull(key='X_test', task_ids='load_test_data')
    y_test = ti.xcom_pull(key='y_test', task_ids='load_test_data')
    
    sqs = boto3.client('sqs', region_name=AWS_REGION)
    
    sent_count = 0
    failed_count = 0
    
    for idx, (features, true_label) in enumerate(zip(X_test, y_test)):
        record_id = f"sample_{idx:04d}"
        
        message = {
            "record_id": record_id,
            "features": features,
            "true_label": int(true_label)  # Include for validation purposes
        }
        
        try:
            response = sqs.send_message(
                QueueUrl=SQS_QUEUE_URL,
                MessageBody=json.dumps(message)
            )
            sent_count += 1
            
            if sent_count % 20 == 0:
                print(f"Sent {sent_count} messages...")
                
        except Exception as e:
            print(f"Failed to send message {record_id}: {e}")
            failed_count += 1
    
    print(f"\n✅ Successfully sent {sent_count} messages to SQS")
    if failed_count > 0:
        print(f"⚠️  Failed to send {failed_count} messages")
    
    print(f"Queue URL: {SQS_QUEUE_URL}")

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
    dag_id='breast_cancer_inference_queue',
    default_args=default_args,
    description='Send test dataset to SQS for inference',
    schedule_interval=None,  # Manual trigger
    start_date=days_ago(1),
    catchup=False,
    tags=['ml', 'inference', 'sqs'],
) as dag:
    
    load_task = PythonOperator(
        task_id='load_test_data',
        python_callable=load_test_data,
        provide_context=True,
    )
    
    send_task = PythonOperator(
        task_id='send_to_sqs',
        python_callable=send_to_sqs,
        provide_context=True,
    )
    
    load_task >> send_task
