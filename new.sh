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
case $choice in
    add)
        git add . 
        MSG="added"
        ;;
    commit)
        git commit -m "$commit_msg" || echo "No changes to commit."
        MSG="Committed"
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
}
run "$1" "$2"
echo "$MSG"