#!/usr/bin/env bash
# Launch wrapper para Claude Code — injeta identidade do usuário Linux na telemetria OTEL.
# Necessário porque devs compartilham a mesma conta Claude (user.email idêntico).
# Deploy: /usr/local/bin/claude (root:root 755) — PATH precede /usr/bin/claude (binário real).
#
# Fonte única de OTEL_RESOURCE_ATTRIBUTES (managed-settings NÃO define essa var, evita conflito de precedência).

export OTEL_RESOURCE_ATTRIBUTES="org=TBC,team.id=dev,plan=teams,enduser.id=$(id -un),host.name=$(hostname)"

exec /usr/bin/claude "$@"
