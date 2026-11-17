#!/bin/sh
#-------------------------------
# Ask for environment
#---------------------------
echo "Select environment:"
echo "1) dev"
echo "2) prod"
read -p "Enter choice (dev or prod): " env_choice

#-----------------------
# Case scenario
#---------------------------
# case $env_choice in
#     dev)
#         ENV="dev"
#         ;;
#     prod)
#         ENV="prod"
#         ;;
#     *)
#         echo "Invalid choice. Exiting."
#         exit 1
#         ;;
# esac
#
# echo " You typed: $env_choice"

#--------------------
# nested if else
#---------------------
if [ "$env_choice" = "dev" ]; then
    echo "You typed dev"

elif [ "$env_choice" = "prod" ]; then
    echo "You typed prod"

else
    echo "Invalid choice. Exiting."
    exit 1
fi
