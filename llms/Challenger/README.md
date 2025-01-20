## Setup

- prepare a conda environment with python dependencies of `llama_cpp_canister` repo

  ```bash
  conda create --name llama_cpp_canister python=3.11
  conda activate llama_cpp_canister

  # from llama_cpp_canister root folder
  pip install -r requirements.txt

  # We used dfx 0.24.3 (installed with dfxvm)
  sh -ci "$(curl -fsSL https://internetcomputer.org/install.sh)"

  dfx --version
  ```

## Deploy

### Deploy the Challenger LLM canisters

```bash
# from folder `DecentralizedAIonIC/PoAIW/llms/Challenger`:

conda activate llama_cpp_canister

# when running local, start dfx (if not yet done)
dfx start --clean

# WARNING: This will re-deploy all the llm canisters with loss of all existing data!
scripts/deploy.sh --network [local/ic]
```

### Deploy the challenger_ctrlb_canister

When deploying local, before continuing, go to the `DecentralizedAIonIC/PoAIW/src/Challenger` folder, and deploy the challenger_ctrlb_canister.

```bash
# from PoAIW/src/Challenger folder
% scripts/deploy.sh --network [local/ic]
```

### Make challenger_ctrlb_canister a controller of LLMs

```bash
scripts/register-ctrlb-canister.sh --network [local/ic]
```

## Verify

```bash
scripts/ready.sh --network [local/ic]
```

## Check cycle balance

```bash
scripts/balance.sh --network [local/ic]
```

## Top up cycles

```bash
# Edit the value of TOPPED_OFF_BALANCE_T in the script.
scripts/top-off.sh --network [local/ic]
```