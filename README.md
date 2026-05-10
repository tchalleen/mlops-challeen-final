# MLOps Final Project

Distributed ML inference system using Airflow, S3, SQS, and scalable consumers.

## Setup (AWS Cloud9)

```bash
# 1. Clone repository
cd ~/environment
git clone git@github.com:tchalleen/mlops-challeen-final.git
cd mlops-challeen-final

# 2. Install Airflow
./scripts/install_airflow_cloud9.sh

# 3. Setup Airflow
source venv/bin/activate
./scripts/setup_airflow.sh

# 4. Migrate database
airflow db migrate

# 5. Start Airflow
./scripts/start_airflow_cloud9.sh
```

**Access Airflow:** Cloud9 → Preview → Preview Running Application  
**Login:** admin / admin

## Run Pipeline

### Train Model

```bash
source venv/bin/activate
airflow dags unpause breast_cancer_training
airflow dags trigger breast_cancer_training
```

**Verify:**
```bash
aws s3 ls s3://tony-mlops-2026/models/
```

### Send Test Data to Queue

```bash
airflow dags unpause breast_cancer_inference_queue
airflow dags trigger breast_cancer_inference_queue
```

**Verify:**
```bash
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/576524850000/mlops-tonychalleen-final \
  --attribute-names ApproximateNumberOfMessages
```

### Run Consumer

```bash
cd ~/environment/mlops-challeen-final/consumer
source ../venv/bin/activate
pip install -r requirements.txt
python consumer.py
```

**Verify Results:**
```bash
aws s3 ls s3://tony-mlops-2026/predictions/
```

## Architecture

- **Training:** Airflow → sklearn model → S3
- **Inference:** Airflow → SQS → Consumer → S3
- **Dataset:** Breast cancer (569 samples, 30 features)
- **Model:** Logistic Regression (~95% accuracy)

## Scaling

Run multiple consumers in separate terminals to process messages in parallel.

## Troubleshooting

**Can't login to Airflow:**
```bash
source venv/bin/activate
export AIRFLOW_HOME=$(pwd)/airflow
./scripts/reset_admin_password.sh
./scripts/stop_airflow.sh
./scripts/start_airflow_cloud9.sh
```

**Consumer errors:**
```bash
cd ~/environment/mlops-challeen-final
git pull origin main
cd consumer
source ../venv/bin/activate
python consumer.py
```

**Restart everything:**
```bash
cd ~/environment/mlops-challeen-final
source venv/bin/activate
./scripts/cleanup_airflow.sh
airflow db migrate
./scripts/start_airflow_cloud9.sh
```
