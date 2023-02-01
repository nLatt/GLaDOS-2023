# GLaDOS-2023
  

# Install Dependencies

```sh
yay -S ghc cabal-install cabal-static  haskell-tf-random haskell-random haskell-quickcheck haskell-quickcheck-io  haskell-hunit hlint;

cabal update;
```

Also install the following VSCode/Codium/CodeOSS extensions:
```
hoovercj.haskell-linter
justusadam.language-haskell
haskell.haskell
```

# Run project

```sh
cabal run;
```

# Running the tests

In order to see coloured output and no coverage when running the tests, please run the tests with the following commands:

```
cabal run test
```

# Bonus ideas :

- Fully featured REPL
- Exception stack tracing
- Exception line tracing
