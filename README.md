# PoAIW

Clone this repo into DecentralizedAIonIC

# Setup

- clone the following repos to your local disk in this folder structure:

  ```
  |-DecentralizedAIonIC       (https://github.com/patnorris/DecentralizedAIonIC)
    |-PoAIW                   (https://github.com/onicai/PoAIW)

  |-llama_cpp_canister        (https://github.com/onicai/llama_cpp_canister)
    |-src
      |-llama_cpp_onicai_fork (https://github.com/onicai/llama_cpp_onicai_fork)
  ```

  Note: The folder structure is important, because the scripts use relative paths.


- Deploy canisters:

  Follow instructions the README files:

  *Note: Do it in exactly this order, because dfx updates the `.env` files with the canister ids, and the scripts read from those files.*

  - Step 1a: deploy llms/Challenger
  - Step 1b: deploy src/Challenger