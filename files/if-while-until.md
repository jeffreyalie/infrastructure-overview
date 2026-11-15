# if else wile until

Table of content

* [Commands exit code](#every-command-gives-an-exit-code)
* [about [...]](#-is-the-same-but-its-success-means-the-comparison-was-true)
* [Operators and [...]](#operators-and---)
* [$?](#about-)
* ['&& and ||'](#-and-)
* [Operators](#operators)
* [Wile / Until](#while---until-loops)
* [If else](#if--else)


## Every command gives an exit code

Whenever a command finishes, it returns a number (0 to 255\) to the shell. That includes `ping`, `nc`, `ls`, `grep`, `cp`, and `[`.

bash

```sh
ls /etc
echo $?      # 0, directory exists

ls /nonexistent
echo $?      # 2, error (ls uses 2 for "can't access")

ping -c 1 127.0.0.1
echo $?      # 0

nc -z localhost 9999
echo $?      # 1, nothing listening
```

* **0** means success  
* **non-zero** means failure

## `[` is the same, but its “success” means the comparison was true

`[` does the comparison itself, then exits with a code based on the result:

bash

```sh
[ 10 -gt 5 ]
echo $?      # 0, comparison true

[ 3 -gt 5 ]
echo $?      # 1, comparison false
```

So for `[`:

* `-eq`, `-le`, `-gt` and the others are just arguments telling it **which comparison to do**  
* true becomes exit code **0**  
* false becomes exit code **1**

## Operators and `[ ... ]`

Yes, `-eq`, `-le`, `=`, `-f`, `-d` and the rest are all **arguments to `[`**. They tell it which test to run. They also work with `[[ ... ]]` and `test`.

bash

```sh
[ $a -le 5 ]        # number comparison
[ "$s" = "bob" ]    # string comparison
[ -f /etc/hosts ]   # file test
```

## About $?

`$?` holds the exit code of the last command. If nothing is listening, it prints `1`. If something is listening, it prints `0`.

## && and \|\|

* `&&`: run the next command only if the previous one **succeeded** (exit 0\)

* `||`: run the next command only if the previous one **failed** (non-zero)



## Operators

### **All the numeric operators**

| Operator | Meaning |
| ----- | ----- |
| `-eq` | equal to (=) |
| `-ne` | not equal to (≠) |
| `-lt` | less than (\<) |
| `-le` | less than or equal to (≤) |
| `-gt` | greater than (\>) |
| `-ge` | greater than or equal to (≥) |

### **Common file test operators**

| Operator | True if... |
| ----- | ----- |
| `-f path` | it exists and is a **regular file** |
| `-d path` | it exists and is a **directory** |
| `-e path` | it exists (file, directory, anything) |
| `-r path` | it is **readable** |
| `-w path` | it is **writable** |
| `-x path` | it is **executable** |
| `-s path` | it exists and is **not empty** (size \> 0\) |
| `-L path` | it is a **symbolic link** |
| `-z "$str"` | string is **empty** |
| `-n "$str"` | string is **not empty** |

Use `!` to negate:

## While /  until Loops

while loop  
Runs as long as the condition is true.  
until loop  
Runs until the condition becomes true (the opposite of while).

#### **`while` loop syntax**

bash

```sh
while command; do    # run command, check exit code
    ...              # exit 0: run this body, then go back to the top
done                 # non-zero: stop the loop, continue after done
```

`while` keeps looping **as long as the command succeeds** (exit 0).

bash

```sh
count=1
while [ $count -le 5 ]; do    # [ ] returns 0 while count <= 5
    echo "Count is: $count"
    ((count++))               # increase count, so the condition eventually fails
done
```

#### **`until` loop syntax**

bash

```sh
until command; do    # run command, check exit code
    ...              # non-zero: run this body, then go back to the top
done                 # exit 0: stop the loop, continue after done
```

`until` keeps looping **as long as the command fails** (non-zero). It is the opposite of `while`.

bash

```sh
until nc -z localhost 8080; do    # nc fails while the port is closed
    echo "Waiting for port 8080..."
    sleep 2                       # pause between checks
done
echo "Service is up!"             # runs once nc succeeds (port open)
```

#### **Comparison**

| Loop | Runs the body while exit code is... | Stops when exit code is... |
| :---- | :---- | :---- |
| `while` | 0 (success) | non-zero (failure) |
| `until` | non-zero (failure) | 0 (success) |

## 

## if / else

Yes, `if` works exactly the same way. It runs a command, checks the exit code, and decides which branch to take.

### **The rule**

```
if command; then      # exit code 0 (success) -> run this block
    ...
else                  # exit code non-zero (failure) -> run this block
    ...
fi
```

Same table as before:

| Exit code | `if` does |
| :---- | :---- |
| 0 | runs the `then` block |
| non-zero | runs the `else` block (or skips if there is no `else`) |

### **Examples with each kind of condition**

**Comparison with `[ ]`:**

bash

```sh
count=3
if [ $count -le 5 ]; then
    echo "5 or less"
else
    echo "more than 5"
fi
```

