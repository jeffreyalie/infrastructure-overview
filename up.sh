#!/bin/sh
#-------------------------------
# Ask for environment
#---------------------------
echo "Select environment:"
echo "add"
echo "commit"
echo "push"
echo "all"
read -p "Enter choice (1-4): " choice

#-----------------------
# Case scenario
#---------------------------
case $choice in
    add)
        git add . 
        MSG="added"
        ;;
    commit)
        read -p "Enter commit message: " commit_msg
        git commit -m "$commit_msg" || echo "No changes to commit."
        MSG="Committed"
        ;;
    push)
        git push origin main && git push github main
        MSG="pushed"
        ;;
    all)
        git add .
        read -p "Enter commit message: " commit_msg
        git commit -m "$commit_msg" || echo "No changes to commit."
        git push origin main && git push github main
        MSG="all done"
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo "$MSG"