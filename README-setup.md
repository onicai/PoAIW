# PoAIW setup instructions

## Clone

Clone the following repos to your local disk using this folder structure:

```
|-funnAI       (https://github.com/onicai/funnAI)
  |-PoAIW      (https://github.com/onicai/PoAIW)
```

Note: The folder structure is important, because the scripts use relative paths.

## Miniconda

Create a conda environment with python dependencies of `llama_cpp_canister` repo

```bash
# install Miniconda on your system

# create a conda environment
conda create --name llama_cpp_canister python=3.11
conda activate llama_cpp_canister

# from folder: PoAIW/llms/llama_cpp_canister
pip install -r requirements.txt
```

## mops

Install mops (https://mops.one/docs/install), and then:

```bash
# Do this in all these folders:
# - from folder: `PoAIW/src/Challenger`
# - from folder: `PoAIW/src/Judge`
# - from folder: `PoAIW/src/mAIner`
mops install
```

## Install dfx

```bash
sh -ci "$(curl -fsSL https://internetcomputer.org/install.sh)"
```

# Download the LLMs from HuggingFace

## Download LLM model (gguf)

Download the model `qwen2.5-0.5b-instruct-q8_0.gguf` from huggingface: https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF

Store it in: 
```
PoAIW/llms/models/Qwen/Qwen2.5-0.5B-Instruct-GGUF/qwen2.5-0.5b-instruct-q8_0.gguf
```

# Deploy ALL canisters:

Follow instructions of:
- funnAI/README.md
- README-prd-upgrade-commands.md

# Admin RBAC

Admin Role-Based Access Control allows non-controller principals to call admin endpoints without requiring full controller privileges.

## Role Hierarchy

```
controller > AdminUpdate > AdminQuery
```

- **Controllers** always pass all admin checks
- **AdminUpdate** role includes AdminQuery permissions
- **AdminQuery** role only has query permissions

## Canisters with Admin RBAC

- GameState canister
- API canister
- mAIner canisters

## Management Endpoints (Controller-Only)

| Endpoint           | Description                        |
| ------------------ | ---------------------------------- |
| `assignAdminRole`  | Assign an admin role to a principal |
| `revokeAdminRole`  | Revoke an admin role from a principal |
| `getAdminRoles`    | List all admin role assignments    |

## Usage Examples

```bash
# Assign AdminQuery role
dfx canister --network $NETWORK call <canister> assignAdminRole \
  '( record { "principal" = "<principal-id>"; role = variant { AdminQuery }; note = "Description" } )'

# Assign AdminUpdate role
dfx canister --network $NETWORK call <canister> assignAdminRole \
  '( record { "principal" = "<principal-id>"; role = variant { AdminUpdate }; note = "Description" } )'

# List all admin role assignments
dfx canister --network $NETWORK call <canister> getAdminRoles

# Revoke an admin role
dfx canister --network $NETWORK call <canister> revokeAdminRole '( "<principal-id>" )'
```