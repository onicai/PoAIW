#!/bin/bash

#######################################################################
# run from parent folder as:
# scripts/deploy-all.sh --mode [install/reinstall/upgrade] --network [local/ic]
#######################################################################

echo " "
echo "This script (PoAIW/scripts/deploy-all.sh) is no longer maintaned. Please use the new scripts in the funnAI folder."
echo " "

# # Default network type is local
# NETWORK_TYPE="local"
# DEPLOY_MODE="install"

# # Parse command line arguments for network type
# while [ $# -gt 0 ]; do
#     case "$1" in
#         --network)
#             shift
#             if [ "$1" = "local" ] || [ "$1" = "ic" ] || [ "$1" = "testing" ] || [ "$1" = "development" ] || [ "$1" = "demo" ] || [ "$1" = "prd" ]; then
#                 NETWORK_TYPE=$1
#             else
#                 echo "Invalid network type: $1. Use 'local' or 'ic' or 'testing' or 'development' or 'demo' or 'prd'."
#                 exit 1
#             fi
#             shift
#             ;;
#         --mode)
#             shift
#             if [ "$1" = "install" ] || [ "$1" = "reinstall" ] || [ "$1" = "upgrade" ]; then
#                 DEPLOY_MODE=$1
#             else
#                 echo "Invalid mode: $1. Use 'install', 'reinstall' or 'upgrade'."
#                 exit 1
#             fi
#             shift
#             ;;
#         *)
#             echo "Unknown argument: $1"
#             echo "Usage: $0 --network [local|ic]"
#             exit 1
#             ;;
#     esac
# done

# echo "Using network type: $NETWORK_TYPE"

# #######################################################################
# scripts/deploy-mainer-creator.sh     --network $NETWORK_TYPE --mode $DEPLOY_MODE
# scripts/deploy-challenger.sh --network $NETWORK_TYPE --mode $DEPLOY_MODE
# scripts/deploy-judge.sh      --network $NETWORK_TYPE --mode $DEPLOY_MODE
# scripts/deploy-mainer.sh     --network $NETWORK_TYPE --mode $DEPLOY_MODE
# scripts/deploy-gamestate.sh  --network $NETWORK_TYPE --mode $DEPLOY_MODE