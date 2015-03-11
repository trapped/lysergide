## Lysergide
Lysergide is a Ruby/Sinatra Continuous Integration service meant to replace in-house Jenkins as a simpler but less secure alternative.

It uses the [Acid](https://github.com/trapped/acid) gem.

####`lsd`
`lsd` is the command line utility provided with Lysergide. It is recommended to use it for most tasks.

`lsd` supports the following commands:

- `start [port]` starts Lysergide on the specified port (default 3000); if no command is supplied, `start` is implicitly chosen
- `populate [name[ email[ password]]]` initializes the Sqlite database and/or adds the first user with the specified data (default 'admin' 'admin@example.com' 'admin')
- `destroy` prompts the user to permanently delete the database (10s timeout)