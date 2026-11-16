# Function

And any command, including your own functions, can be used as a loop condition:

```bash
check_ready() {
    [ -f /tmp/ready.txt ]    # returns 0 if file exists, 1 if not
}

until check_ready; do
    echo "Waiting for file..."
    sleep 1
done
```
---
```bash
check_ready() {
    [ -f /tmp/ready.txt ]    # exit 0 if file exists, 1 if not
}

if check_ready; then
    echo "file found"
else
    echo "file not found"
fi
```
---
```bash
file_exists() {
    [ -f "$1" ]
}

if file_exists /tmp/ready.txt; then
    echo "file found"
fi

if file_exists j.sh; then
    echo "j.sh found"
fi
```