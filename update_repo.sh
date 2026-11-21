#!/bin/sh

#-------------------------------
# Script to run git commands
#-------------------------------
run() {
    local choice="$1"
    local commit_msg="$2"
    if [ -z "$choice" ]; then
        echo "Usage"
        echo "Enter choice (add, commit <message>, push, all)"
        exit 1
    else
case $choice in
    add)
        git add . && MSG="added successfully to local repository" || echo "error."
        ;;
    commit)
        if [ -z "$commit_msg" ]; then
            echo "Enter commit <message>"
            exit 1
        else
        git commit -m "$commit_msg" &&  MSG="committed successfully" || echo "error."
        fi
        ;;
    push)
        git push origin main && git push github main  && MSG="pushed successfully" || echo "error."
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac
fi
}
run "$1" "$2"
echo "$MSG"