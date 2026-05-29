# tmux auto-attach (vps-tbc) — só em SSH interativo, fora de tmux
# Append ao ~/.bashrc do dev. Cada SSH cai na sessão 'main' (persiste no servidor).
if [ -n "$PS1" ] && [ -z "$TMUX" ] && [ -n "$SSH_CONNECTION" ]; then
  tmux attach -t main 2>/dev/null || tmux new -s main
fi
