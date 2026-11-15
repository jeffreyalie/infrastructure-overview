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