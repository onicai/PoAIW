## Setup

- clone the following repos to your local disk in this folder structure:

  ```
  |-DecentralizedAIonIC       (https://github.com/patnorris/DecentralizedAIonIC)
    |-PoAIW                   (https://github.com/onicai/PoAIW)

  |-llama_cpp_canister        (https://github.com/onicai/llama_cpp_canister)
    |-src
      |-llama_cpp_onicai_fork (https://github.com/onicai/llama_cpp_onicai_fork)
  ```

  Note: The folder structure is important, because the scripts use relative paths.

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

# when running local, start dfx
dfx start --clean

# WARNING: This will re-deploy all the llm canisters with loss of all existing data!
scripts/deploy.sh --network [local/ic]
```

### Deploy the challenger_ctrlb_canister

When deploying local, before continuing, go to the `DecentralizedAIonIC/PoAIW/src/Challenger` folder, and deploy the challenger_ctrlb_canister. Note down the canister id.

```bash
# from PoAIW/src/Challenger folder
% scripts/deploy.sh --network [local/ic]
challenger_ctrlb_canister canister created with canister id: bw4dl-smaaa-aaaaa-qaacq-cai
```

### Make challenger_ctrlb_canister a controller

The LLM canisters can only be called by a controller, which is handled by `whitelist.sh`

```bash
# Update in all the scripts:
NETWORK_TYPE="local"
CTRLB_PRINCIPAL="bw4dl-smaaa-aaaaa-qaacq-cai"

# Then run it
scripts/whitelist.sh --network [local/ic]
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