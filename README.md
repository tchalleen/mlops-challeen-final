# MLOps Final Project - Distributed ML Inference System

Breast cancer classification using Airflow orchestration, S3 storage, SQS messaging, and scalable consumers.

**Architecture:** Airflow → Train Model → S3 → SQS → Consumer → Predictions

---

## Quick Start (AWS Cloud9)

```bash
cd ~/environment
git clone git@github.com:tchalleen/mlops-challeen-final.git
cd mlops-challeen-final

./scripts/install_airflow_cloud9.sh
source venv/bin/activate
export AIRFLOW_HOME=$(pwd)/airflow
./scripts/setup_airflow.sh
airflow db migrate
./scripts/start_airflow_cloud9.sh
sleep 60
```

---

## Run Pipeline

```bash
source venv/bin/activate
export AIRFLOW_HOME=$(pwd)/airflow

# Train model
airflow dags unpause breast_cancer_training
airflow dags trigger breast_cancer_training
sleep 60
airflow dags list-runs -d breast_cancer_training | grep success

# Send test data to queue
airflow dags unpause breast_cancer_inference_queue
airflow dags trigger breast_cancer_inference_queue
sleep 60
airflow dags list-runs -d breast_cancer_inference_queue | grep success

# Run consumer
cd consumer
python consumer.py
# Press Ctrl+C after processing completes
```

---

## Verify All Requirements

```bash
cd ~/environment/mlops-challeen-final
source venv/bin/activate
export AIRFLOW_HOME=$(pwd)/airflow
./scripts/verify_all.sh
```

**Expected Output:**
- ✅ Training DAG: success
- ✅ Model in S3: breast_cancer_model.pkl + model_metadata.json
- ✅ Inference DAG: success
- ✅ SQS Queue: 0 messages (all processed)
- ✅ Predictions: 114 files in S3
- ✅ Kubernetes YAML: deployment.yaml exists

---

## Project Structure

```
├── dags/
│   ├── training_dag.py              # Train model, save to S3
│   └── inference_queue_dag.py       # Send test data to SQS
├── consumer/
│   ├── consumer.py                  # Process SQS messages, run inference
│   ├── Dockerfile                   # Container image
│   └── requirements.txt             # Dependencies
├── kubernetes/
│   └── deployment.yaml              # K8s deployment spec
└── scripts/
    ├── install_airflow_cloud9.sh    # Install dependencies
    ├── setup_airflow.sh             # Configure Airflow
    ├── start_airflow_cloud9.sh      # Start services
    └── verify_all.sh                # Verify all requirements
```

---

## Key Details

- **Dataset:** Breast cancer (569 samples, 30 features)
- **Model:** Logistic Regression (~95% accuracy)
- **S3 Bucket:** tony-mlops-2026
- **SQS Queue:** mlops-tonychalleen-final
- **Test Samples:** 114 (20% of dataset)

---

## Troubleshooting

**DAGs not found?**
```bash
export AIRFLOW_HOME=$(pwd)/airflow
sleep 30
airflow dags list | grep breast_cancer
```

**Reset everything:**
```bash
cd ~/environment
rm -rf mlops-challeen-final
git clone git@github.com:tchalleen/mlops-challeen-final.git
cd mlops-challeen-final
# Run setup commands above
```

**Note:** Airflow UI login doesn't work in Cloud9 (iframe issue). Use CLI only.
