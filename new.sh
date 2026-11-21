#!/bin/sh
#-------------------------------
# Ask for environment
#---------------------------
# echo "Select environment:"
# echo "add"
# echo "commit"
# echo "push"
# echo "all"

#-----------------------
# Case scenario
#---------------------------
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
        git add . 
        MSG="added"
        ;;
    commit)
        if [ -z "$commit_msg" ]; then
            echo "Enter commit <message>"
            exit 1
        else
        git commit -m "$commit_msg" || echo "No changes to commit."
        MSG="Committed"
        fi
        ;;
    push)
        git push origin main && git push github main
        MSG="pushed"
        ;;
    all)
        git add .
        git commit -m "$commit_msg" || echo "No changes to commit."
        git push origin main && git push github main
        MSG="all done"
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