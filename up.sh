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
        func () {
            git commit -m "$1" || echo "No changes to commit."
        }
        func
        MSG="Committed"
        ;;
    push)
        git push origin main && git push github main
        MSG= "pushed"
        ;;
    all)
        git add .
        func () {
            git commit -m "$1" || echo "No changes to commit."
        }
        func
        git push origin main && git push github main
        MSG="all"
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo "$MSG"