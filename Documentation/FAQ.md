# FAQ

## Help! Hermes crashes on startup or behaves badly!

Try resetting all saved state, Preferences, and anything else Hermes related:

1. Exit Hermes
2. Remove `~/Library/Application Support/Hermes/`
3. Remove `~/Library/Preferences/com.alexcrichton.Hermes.plist`
4. Remove `~/Library/Caches/com.alexcrichton.Hermes/` 
5. Remove Hermes from keychain
    1. Open Keychain Access
    2. Search for "Hermes"
    3. Select all items named "Hermes"
    4. Click on Edit → Delete

The following shell script should do all the above:

```sh
rm -rf ~/Library/Application\ Support/Hermes
rm -f ~/Library/Preferences/com.alexcrichton.Hermes.plist
rm -rf ~/Library/Caches/com.alexcrichton.Hermes
while [ $? -eq 0 ]; do security delete-generic-password -l Hermes >/dev/null 2>&1; done
```

If you had to use these steps, chances are there is a bug that should be reported.
All bug reports are welcome on the [issue tracker](https://github.com/HermesApp/Hermes/issues).
