{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    elixir
    erlang
  ];

  # Set environment variables if needed
  shellHook = ''
    echo "Elixir $(elixir --version | grep Elixir | cut -d ' ' -f 2) on Erlang $(erl -eval 'io:fwrite("~s~n", [erlang:system_info(otp_release)]), halt().' -noshell) environment loaded."
    export ERL_AFLAGS="-kernel shell_history enabled"
  '';
}
