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
export AIRFLOW_HOME=$(pwd)/airflow
./scripts/setup_airflow.sh

# 4. Migrate database
airflow db migrate

# 5. Start Airflow
./scripts/start_airflow_cloud9.sh

# 6. Set AIRFLOW_HOME for all future commands
export AIRFLOW_HOME=$(pwd)/airflow
```

**Note:** No UI needed - all commands run via CLI below

## Run Pipeline

### Train Model

```bash
source venv/bin/activate
export AIRFLOW_HOME=$(pwd)/airflow

airflow dags unpause breast_cancer_training
airflow dags trigger breast_cancer_training

# Check status
airflow dags list-runs -d breast_cancer_training --no-backfill | head -5
```

**Verify:**
```bash
aws s3 ls s3://tony-mlops-2026/models/
# Should show: breast_cancer_model.pkl and model_metadata.json
```

### Send Test Data to Queue

```bash
airflow dags unpause breast_cancer_inference_queue
airflow dags trigger breast_cancer_inference_queue

# Check status
airflow dags list-runs -d breast_cancer_inference_queue --no-backfill | head -5
```

**Verify:**
```bash
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/576524850000/mlops-tonychalleen-final \
  --attribute-names ApproximateNumberOfMessages
# Should show ~114 messages
```

### Run Consumer

```bash
cd consumer
source ../venv/bin/activate
python consumer.py
# Press Ctrl+C when done
```

**Verify Results:**
```bash
aws s3 ls s3://tony-mlops-2026/predictions/ | wc -l
# Should show: 114

# View sample prediction
aws s3 cp s3://tony-mlops-2026/predictions/sample_0001.json - | jq .
```

## Architecture

- **Training:** Airflow → sklearn model → S3
- **Inference:** Airflow → SQS → Consumer → S3
- **Dataset:** Breast cancer (569 samples, 30 features)
- **Model:** Logistic Regression (~95% accuracy)

## Scaling

Run multiple consumers in separate terminals to process messages in parallel.

## Common Issues & Solutions

### Issue 1: DAGs Not Found

**Problem:** `airflow dags trigger` returns "Dag id not found"

**Cause:** `AIRFLOW_HOME` environment variable not set correctly

**Solution:**
```bash
cd ~/environment/mlops-challeen-final
source venv/bin/activate
export AIRFLOW_HOME=$(pwd)/airflow

# Verify correct path
airflow config get-value core dags_folder
# Should show: /home/ec2-user/environment/mlops-challeen-final/airflow/dags

# Wait for scheduler to scan DAGs
sleep 30
airflow dags list | grep breast_cancer
```

**⚠️ Critical:** Always run `export AIRFLOW_HOME=$(pwd)/airflow` before any `airflow` command.

---

### Issue 2: Airflow UI Login Fails in Cloud9

**Problem:** Cannot login to Airflow UI via Cloud9 Preview

**Cause:** Cloud9 iframe has cookie/session issues that prevent authentication

**Solution:** **Use CLI instead - UI not required**
```bash
# All operations work via command line
source venv/bin/activate
export AIRFLOW_HOME=$(pwd)/airflow
airflow dags list
airflow dags trigger breast_cancer_training
```

**Note:** The UI login issue is a Cloud9 limitation, not an Airflow problem. All functionality is available via CLI.

---

### Issue 3: Consumer "Invalid format specifier" Error

**Problem:** Consumer fails with `Invalid format specifier` when processing messages

**Cause:** Python f-string syntax error in logging statement

**Solution:** Already fixed in latest code. If you see this error:
```bash
cd ~/environment/mlops-challeen-final
git pull origin main
cd consumer
source ../venv/bin/activate
python consumer.py
```

---

### Issue 4: XCom Serialization Error in Training DAG

**Problem:** `train_model` task fails with "Object of type LogisticRegression is not JSON serializable"

**Cause:** Airflow cannot serialize sklearn model objects through XCom

**Solution:** Already fixed - model is now saved directly to S3 instead of passing through XCom.

If you see this error, ensure you have the latest code:
```bash
git pull origin main
```

---

### Issue 5: Database Not Initialized

**Problem:** `airflow dags unpause` fails with "no such table: dag"

**Cause:** Database migration not run after setup

**Solution:**
```bash
source venv/bin/activate
export AIRFLOW_HOME=$(pwd)/airflow
airflow db migrate
./scripts/stop_airflow.sh
./scripts/start_airflow_cloud9.sh
sleep 30
```

---

### Issue 6: Broken Pipe Error with `head` Command

**Problem:** `BrokenPipeError` when using `airflow dags list-runs | head -5`

**Cause:** Harmless - occurs when `head` closes pipe before Airflow finishes output

**Solution:** Ignore the error or use alternative commands:
```bash
# Instead of piping to head, use grep
airflow dags list-runs -d breast_cancer_training | grep success

# Or view without piping
airflow dags list-runs -d breast_cancer_training --no-backfill
```

---

## Complete Reset (If Everything Breaks)

If you need to start completely fresh:

```bash
cd ~/environment
rm -rf mlops-challeen-final
git clone git@github.com:tchalleen/mlops-challeen-final.git
cd mlops-challeen-final

# Follow setup steps from top of README
./scripts/install_airflow_cloud9.sh
source venv/bin/activate
export AIRFLOW_HOME=$(pwd)/airflow
./scripts/setup_airflow.sh
airflow db migrate
./scripts/start_airflow_cloud9.sh
```
