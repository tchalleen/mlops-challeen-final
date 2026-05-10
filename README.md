# MLOps Final Project: Distributed ML Inference System

**A complete ML pipeline using Airflow, S3, SQS, and Kubernetes for asynchronous model training and inference.**

This guide assumes you're setting up in **AWS Cloud9** for the first time.

---

## Architecture

```
Training:  Airflow → Load Data → Train Model → Save to S3
Inference: Airflow → Send to SQS → Consumers → Inference → Save to S3
```

**Components:**
- **Airflow**: Orchestrates training and queue population
- **S3**: Stores model and predictions (`tony-mlops-2026`)
- **SQS**: Message queue (`mlops-tonychalleen-final`)
- **Consumer**: Polls SQS, runs inference, saves results

---

## Quick Start (Cloud9)

### Step 1: Clone Repository

```bash
cd ~/environment
git clone git@github.com:tchalleen/mlops-challeen-final.git
cd mlops-challeen-final
```

### Step 2: Install Airflow

```bash
# This script handles all Cloud9 compatibility issues
./scripts/install_airflow_cloud9.sh
```

**What it does:**
- Creates virtual environment
- Installs Airflow using constraints file (avoids compilation errors)
- Installs AWS providers, scikit-learn, boto3

### Step 3: Setup Airflow

```bash
source venv/bin/activate
./scripts/setup_airflow.sh
```

**What it does:**
- Initializes Airflow database
- Creates admin user (admin/admin)
- Copies DAGs to Airflow directory
- Auto-detects Cloud9 and configures:
  - Binds webserver to `0.0.0.0` (required for Cloud9 Preview)
  - Disables CSRF protection (fixes login issues)
  - Enables proxy fix

### Step 4: Start Airflow

```bash
./scripts/start_airflow_cloud9.sh
```

**What it does:**
- Installs tmux (if needed)
- Starts webserver and scheduler in tmux session
- Runs in background

### Step 5: Access Airflow UI

1. In Cloud9, click **Preview** → **Preview Running Application**
2. Cloud9 opens preview on port 8080
3. Login with:
   - Username: `admin`
   - Password: `admin`

---

## Running the ML Pipeline

### 1. Train the Model

**In Airflow UI:**
1. Find `breast_cancer_training` DAG
2. Toggle it **ON** (enable)
3. Click **▶** (play button) to trigger
4. Wait ~1-2 minutes for completion

**What it does:**
- Loads sklearn breast cancer dataset (569 samples, 30 features)
- Splits 80/20 train/test
- Trains Logistic Regression model
- Saves model to S3: `s3://tony-mlops-2026/models/breast_cancer_model.pkl`

**Verify:**
```bash
aws s3 ls s3://tony-mlops-2026/models/
```

### 2. Send Test Data to Queue

**In Airflow UI:**
1. Find `breast_cancer_inference_queue` DAG
2. Toggle it **ON**
3. Click **▶** to trigger

**What it does:**
- Loads test dataset (~114 samples)
- Sends each record as JSON message to SQS
- Message format: `{"record_id": "sample_0001", "features": [...], "true_label": 1}`

**Verify:**
```bash
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/576524850000/mlops-tonychalleen-final \
  --attribute-names ApproximateNumberOfMessages
```

### 3. Run Consumer

**In a new Cloud9 terminal:**
```bash
cd ~/environment/mlops-challeen-final/consumer
source ../venv/bin/activate
pip install -r requirements.txt
python consumer.py
```

**What it does:**
- Loads model from S3 (once on startup)
- Polls SQS queue (long polling, 20s)
- Performs inference on each message
- Saves prediction to S3: `s3://tony-mlops-2026/predictions/sample_XXXX.json`
- Deletes message only after successful processing

**You'll see output like:**
```
✅ Model loaded successfully!
✅ Processed sample_0001: prediction=1, confidence=0.9876
✅ Processed sample_0002: prediction=0, confidence=0.9543
```

### 4. Verify Results

```bash
# List predictions
aws s3 ls s3://tony-mlops-2026/predictions/

# View a prediction
aws s3 cp s3://tony-mlops-2026/predictions/sample_0001.json - | python -m json.tool
```

**Prediction format:**
```json
{
  "record_id": "sample_0001",
  "prediction": 1,
  "confidence": 0.9876,
  "true_label": 1,
  "timestamp": "2026-05-10T21:30:00Z"
}
```

---

## Simulating Scale (Multiple Consumers)

To demonstrate horizontal scaling without Kubernetes:

**Terminal 1:**
```bash
cd ~/environment/mlops-challeen-final/consumer
source ../venv/bin/activate
python consumer.py
```

**Terminal 2 (new Cloud9 terminal):**
```bash
cd ~/environment/mlops-challeen-final/consumer
source ../venv/bin/activate
python consumer.py
```

**Terminal 3 (new Cloud9 terminal):**
```bash
cd ~/environment/mlops-challeen-final/consumer
source ../venv/bin/activate
python consumer.py
```

All consumers will process messages in parallel, demonstrating distributed processing.

---

## Managing Airflow

### View Logs
```bash
# Attach to tmux session
tmux attach -t airflow

# Switch between windows:
# Ctrl+B then 0 = webserver
# Ctrl+B then 1 = scheduler

# Detach (keep running): Ctrl+B then D
```

### Stop Airflow
```bash
./scripts/stop_airflow.sh
```

### Restart Airflow
```bash
./scripts/stop_airflow.sh
./scripts/start_airflow_cloud9.sh
```

### Check Status
```bash
# Check if running
ps aux | grep airflow

# Check port 8080
netstat -tuln | grep 8080
```

---

## Troubleshooting

### Can't Access Airflow UI

**Problem:** Preview shows "Cannot GET /"  
**Solution:** Append `/home` to the URL in the preview window

**Problem:** "Bad Request - CSRF token missing"  
**Solution:** Run setup again (it auto-configures CSRF fix):
```bash
source venv/bin/activate
export AIRFLOW_HOME=$(pwd)/airflow
./scripts/configure_airflow_cloud9.sh
./scripts/stop_airflow.sh
./scripts/start_airflow_cloud9.sh
```

### Installation Errors (google-re2)

**Problem:** Compilation error during `pip install`  
**Solution:** Use the Cloud9 install script (already uses constraints file):
```bash
./scripts/install_airflow_cloud9.sh
```

**Manual fix:**
```bash
source venv/bin/activate
AIRFLOW_VERSION=2.10.0
PYTHON_VERSION=3.9
CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"
pip install "apache-airflow==${AIRFLOW_VERSION}" --constraint "${CONSTRAINT_URL}"
pip install apache-airflow-providers-amazon boto3 scikit-learn joblib numpy
```

### DAGs Not Showing

**Check DAG files:**
```bash
ls -la airflow/dags/
```

**Test for Python errors:**
```bash
python airflow/dags/training_dag.py
python airflow/dags/inference_queue_dag.py
```

**Restart scheduler:**
```bash
./scripts/stop_airflow.sh
./scripts/start_airflow_cloud9.sh
```

### Consumer Can't Load Model

**Verify model exists:**
```bash
aws s3 ls s3://tony-mlops-2026/models/breast_cancer_model.pkl
```

**Check AWS credentials:**
```bash
aws sts get-caller-identity
```

**Verify IAM permissions:**
- S3: `GetObject`, `PutObject`
- SQS: `ReceiveMessage`, `DeleteMessage`

### No Messages Processing

**Check queue has messages:**
```bash
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/576524850000/mlops-tonychalleen-final \
  --attribute-names ApproximateNumberOfMessages
```

**Verify consumer is running:**
```bash
ps aux | grep consumer.py
```

**Check consumer logs** in the terminal where it's running

---

## Project Structure

```
mlops-challeen-final/
├── dags/
│   ├── training_dag.py              # Train model, save to S3
│   └── inference_queue_dag.py       # Send test data to SQS
├── consumer/
│   ├── consumer.py                  # Inference worker
│   ├── Dockerfile                   # For Kubernetes deployment
│   └── requirements.txt             # Consumer dependencies
├── kubernetes/
│   └── deployment.yaml              # K8s deployment (optional)
├── scripts/
│   ├── install_airflow_cloud9.sh   # Install with Cloud9 compatibility
│   ├── setup_airflow.sh             # Initialize Airflow (auto-detects Cloud9)
│   ├── start_airflow_cloud9.sh     # Start in tmux
│   ├── stop_airflow.sh              # Stop all services
│   ├── configure_airflow_cloud9.sh # Manual Cloud9 config
│   └── build_and_push.sh            # Docker build/push (for K8s)
├── airflow_requirements.txt         # Airflow dependencies
└── README.md                        # This file
```

---

## Configuration

### AWS Resources

- **S3 Bucket**: `tony-mlops-2026`
  - Models: `models/breast_cancer_model.pkl`
  - Predictions: `predictions/sample_XXXX.json`
  
- **SQS Queue**: `https://sqs.us-east-1.amazonaws.com/576524850000/mlops-tonychalleen-final`
  - Standard queue
  - Long polling: 20s
  - Visibility timeout: 30s

- **Region**: `us-east-1`

### Environment Variables (Consumer)

Set in `consumer/consumer.py` or via environment:
- `S3_BUCKET`: tony-mlops-2026
- `MODEL_KEY`: models/breast_cancer_model.pkl
- `PREDICTIONS_PREFIX`: predictions
- `SQS_QUEUE_URL`: (see above)
- `AWS_REGION`: us-east-1
- `MAX_MESSAGES`: 10
- `VISIBILITY_TIMEOUT`: 30
- `WAIT_TIME`: 20

---

## Optional: Kubernetes Deployment

If you have kubectl access (not available in Cloud9):

```bash
# Build and push Docker image
./scripts/build_and_push.sh

# Deploy to EKS
kubectl apply -f kubernetes/deployment.yaml

# Scale
kubectl scale deployment ml-inference-consumer --replicas=3

# Monitor
kubectl logs -f deployment/ml-inference-consumer
```

**Note:** Cloud9 doesn't have kubectl. Use direct consumer execution instead.

---

## Complete Workflow Summary

```bash
# 1. Install
./scripts/install_airflow_cloud9.sh

# 2. Setup
source venv/bin/activate
./scripts/setup_airflow.sh

# 3. Start Airflow
./scripts/start_airflow_cloud9.sh

# 4. Access UI
# Cloud9: Preview → Preview Running Application
# Login: admin / admin

# 5. Train Model (in Airflow UI)
# Enable and trigger: breast_cancer_training

# 6. Send to Queue (in Airflow UI)
# Enable and trigger: breast_cancer_inference_queue

# 7. Run Consumer (new terminal)
cd consumer
source ../venv/bin/activate
python consumer.py

# 8. Verify
aws s3 ls s3://tony-mlops-2026/predictions/
```

---

## Expected Results

- **Training**: Model saved with ~95%+ accuracy
- **Queue**: 114 messages sent to SQS
- **Inference**: All predictions saved to S3 within 1-2 minutes
- **Scaling**: Multiple consumers process queue faster

---

## Cleanup

```bash
# Stop Airflow
./scripts/stop_airflow.sh

# Stop consumer (Ctrl+C in terminal)

# Purge queue (optional)
aws sqs purge-queue \
  --queue-url https://sqs.us-east-1.amazonaws.com/576524850000/mlops-tonychalleen-final

# Delete predictions (optional)
aws s3 rm s3://tony-mlops-2026/predictions/ --recursive
```

---

## Technical Details

**Dataset:** sklearn breast cancer (569 samples, 30 features, binary classification)  
**Model:** Logistic Regression (max_iter=10000)  
**Train/Test Split:** 80/20 with stratification  
**Test Set Size:** ~114 samples  
**Expected Accuracy:** ~95%+  

**Message Flow:**
1. Airflow sends JSON messages to SQS
2. Consumers poll queue (long polling)
3. Load model from S3 (cached per consumer)
4. Perform inference
5. Save prediction to S3
6. Delete message from queue

---

## Why Cloud9-Specific Configuration?

**CSRF Protection:** Cloud9's proxy causes CSRF validation to fail. We disable it for development.  
**Localhost Binding:** Cloud9 can't access `127.0.0.1`. We bind to `0.0.0.0`.  
**Compilation Errors:** Cloud9 lacks build tools. We use Airflow's constraints file with pre-compiled packages.  
**Multiple Terminals:** tmux makes it easy to manage webserver and scheduler.  
**No Kubernetes:** Cloud9 doesn't have kubectl. We run consumers directly.

All configurations are applied automatically by the setup scripts.

---

## Support

**Issues?**
1. Check troubleshooting section above
2. Verify AWS credentials: `aws sts get-caller-identity`
3. Check Airflow logs: `tmux attach -t airflow`
4. Verify services running: `ps aux | grep airflow`

**Common Commands:**
```bash
# Restart everything
./scripts/stop_airflow.sh && ./scripts/start_airflow_cloud9.sh

# View tmux session
tmux attach -t airflow

# Check what's running
ps aux | grep -E "airflow|consumer"

# Test AWS access
aws s3 ls s3://tony-mlops-2026/
aws sqs get-queue-attributes --queue-url https://sqs.us-east-1.amazonaws.com/576524850000/mlops-tonychalleen-final --attribute-names All
```

---

**That's it! You now have a complete distributed ML inference system running in Cloud9.** 🚀
