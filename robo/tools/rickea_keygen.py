#!/usr/bin/env python3
"""
Gerador de licencas do RickEA MA (versao de vendas).

Formato da chave:

    RMA-<conta>-<validade>-XXXX-XXXX-XXXX-XXXX

    conta     numero da conta MT5 do cliente, ou 0 para "qualquer conta"
    validade  AAAAMMDD do ultimo dia valido, ou 00000000 para vitalicia
    XXXX...   assinatura: 16 primeiros hex do SHA-256 de
              SEGREDO|RICKEA-MA|conta|validade

O robo refaz essa mesma conta e compara. Mexeu na conta ou na data dentro da
chave, a assinatura nao bate mais e a licenca cai.

IMPORTANTE: o SEGREDO precisa ser exatamente o mesmo aqui, no RickEA_MA_Vendas.mq5
e no RickEA_KeyGen.mq5. Troque o padrao antes de vender qualquer copia.

Exemplos:
    python3 rickea_keygen.py --conta 37308561 --dias 30
    python3 rickea_keygen.py --conta 37308561 --ate 2026-12-31
    python3 rickea_keygen.py --conta 0 --vitalicia          # chave mestra
    python3 rickea_keygen.py --lote contas.txt --dias 365   # um numero por linha
"""
import argparse
import hashlib
import sys
from datetime import date, timedelta

DEFAULT_SECRET = "TROQUE-ESTE-SEGREDO-RICKEA-2026"
PRODUCT = "RICKEA-MA"
PREFIX = "RMA"


def signature(secret, account, expiry):
    """16 primeiros hex maiusculos do SHA-256 do payload."""
    payload = "%s|%s|%s|%s" % (secret, PRODUCT, account, expiry)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest().upper()[:16]


def make_key(secret, account, expiry):
    sig = signature(secret, account, expiry)
    grouped = "-".join(sig[i:i + 4] for i in range(0, 16, 4))
    return "%s-%s-%s-%s" % (PREFIX, account, expiry, grouped)


def check_key(secret, key, account=None):
    """Confere uma chave do jeito que o robo confere. Devolve (ok, motivo)."""
    parts = key.strip().upper().split("-")
    if len(parts) != 7 or parts[0] != PREFIX:
        return False, "formato invalido"
    acc, exp = parts[1], parts[2]
    if not acc.isdigit() or not exp.isdigit() or len(exp) != 8:
        return False, "conta ou validade invalida"
    if signature(secret, acc, exp) != "".join(parts[3:]):
        return False, "assinatura nao confere"
    if account is not None and acc != "0" and acc != str(account):
        return False, "chave e da conta %s, nao da %s" % (acc, account)
    if exp != "00000000":
        y, m, d = int(exp[:4]), int(exp[4:6]), int(exp[6:])
        if date(y, m, d) < date.today():
            return False, "vencida em %04d-%02d-%02d" % (y, m, d)
    return True, "ok"


def resolve_expiry(args):
    if args.vitalicia:
        return "00000000"
    if args.ate:
        try:
            y, m, d = (int(v) for v in args.ate.replace("/", "-").split("-"))
        except ValueError:
            sys.exit("--ate precisa ser AAAA-MM-DD")
        return "%04d%02d%02d" % (y, m, d)
    return (date.today() + timedelta(days=args.dias)).strftime("%Y%m%d")


def main():
    ap = argparse.ArgumentParser(description="Gerador de licencas do RickEA MA")
    ap.add_argument("--conta", help="numero da conta MT5 (0 = qualquer conta)")
    ap.add_argument("--lote", help="arquivo com uma conta por linha")
    ap.add_argument("--dias", type=int, default=30, help="validade em dias (padrao 30)")
    ap.add_argument("--ate", help="validade ate a data AAAA-MM-DD")
    ap.add_argument("--vitalicia", action="store_true", help="sem data de validade")
    ap.add_argument("--secret", default=DEFAULT_SECRET, help="segredo (igual ao do robo)")
    ap.add_argument("--conferir", help="confere uma chave em vez de gerar")
    args = ap.parse_args()

    if args.conferir:
        ok, why = check_key(args.secret, args.conferir, args.conta)
        print(("VALIDA  " if ok else "INVALIDA ") + args.conferir + "   (" + why + ")")
        sys.exit(0 if ok else 1)

    if args.secret == DEFAULT_SECRET:
        print("AVISO: usando o segredo padrao. Troque antes de vender.\n", file=sys.stderr)

    expiry = resolve_expiry(args)
    human = "vitalicia" if expiry == "00000000" else "%s-%s-%s" % (expiry[:4], expiry[4:6], expiry[6:])

    contas = []
    if args.lote:
        with open(args.lote) as fh:
            contas = [ln.strip() for ln in fh if ln.strip() and not ln.startswith("#")]
    elif args.conta is not None:
        contas = [args.conta]
    else:
        sys.exit("informe --conta ou --lote")

    for conta in contas:
        if not str(conta).isdigit():
            print("pulando conta invalida: %s" % conta, file=sys.stderr)
            continue
        print("%-14s %-12s %s" % (conta, human, make_key(args.secret, str(conta), expiry)))


if __name__ == "__main__":
    main()
