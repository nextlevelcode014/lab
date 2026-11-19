"""Envia uma mensagem pelo SMTP e localiza o mesmo conteúdo na caixa IMAP."""
import argparse
from contextlib import ExitStack
from email import policy
from email.message import EmailMessage
from email.parser import BytesParser
from email.utils import make_msgid
from getpass import getpass
import imaplib
import os
from pathlib import Path
import smtplib
import ssl
import time

SERVIDOR = "172.30.85.2"
SERVIDOR_CATCH_ALL = "172.30.86.2"
REMETENTE = "ana@example.test"
DESTINATARIO = "bruno@example.test"
CORPO = "Mensagem de teste do Docker Mailserver no lab."
CERTIFICADO = Path(__file__).resolve().parent / "dados/tls/mail.crt"


def montar_mensagem(remetente, destinatario):
    mensagem = EmailMessage()
    mensagem["From"] = remetente
    mensagem["To"] = destinatario
    mensagem["Subject"] = "Ensaio de entrega local"
    mensagem["Message-ID"] = make_msgid(domain="example.test")
    mensagem.set_content(CORPO)
    return mensagem


def enviar(contexto):
    mensagem = montar_mensagem(REMETENTE, DESTINATARIO)
    senha = getpass(f"Senha de {REMETENTE}: ")
    with smtplib.SMTP(SERVIDOR, 587, local_hostname="cliente.example.test", timeout=10) as smtp:
        smtp.starttls(context=contexto)
        smtp.login(REMETENTE, senha)
        smtp.send_message(mensagem)
    print(mensagem["Message-ID"])


def buscar_uids(imap, id_mensagem):
    status, _ = imap.select("INBOX", readonly=True)
    if status != "OK":
        raise SystemExit("Não foi possível selecionar a caixa INBOX")
    status, dados = imap.uid("search", None, "HEADER", "Message-ID", id_mensagem)
    if status != "OK":
        raise SystemExit(f"Não foi possível buscar a mensagem {id_mensagem}")
    return dados[0].split() if dados[0] else []


def conferir_mensagem(imap, id_mensagem, remetente, destinatario):
    limite = time.monotonic() + 30
    while not (uids := buscar_uids(imap, id_mensagem)):
        if time.monotonic() >= limite:
            raise SystemExit(f"Mensagem {id_mensagem} para {destinatario} ausente após 30 s")
        time.sleep(1)

    for uid in uids:
        status, partes = imap.uid("fetch", uid, "(BODY.PEEK[])")
        if status != "OK":
            raise SystemExit(f"Não foi possível ler a mensagem com UID {uid!r}")
        for parte in partes:
            if isinstance(parte, tuple):
                mensagem = BytesParser(policy=policy.default).parsebytes(parte[1])
                if (
                    mensagem["Message-ID"] == id_mensagem
                    and mensagem["From"] == remetente
                    and mensagem["To"] == destinatario
                    and mensagem.get_content().strip() == CORPO
                ):
                    return
    raise SystemExit(f"Conteúdo inesperado para {id_mensagem}")


def conferir(contexto, id_mensagem):
    senha = getpass(f"Senha de {DESTINATARIO}: ")
    with imaplib.IMAP4_SSL(SERVIDOR, 993, ssl_context=contexto, timeout=10) as imap:
        imap.login(DESTINATARIO, senha)
        conferir_mensagem(imap, id_mensagem, REMETENTE, DESTINATARIO)
    print(f"Mensagem {id_mensagem} confirmada na caixa de {DESTINATARIO}")


def ensaiar_catch_all(contexto):
    senha = os.environ["DMS_SENHA_ENSAIO"]
    remetente = "login@origem.example.test"
    rotas = {
        "hello@example.test": DESTINATARIO,
        "work@example.test": DESTINATARIO,
        "sem-cadastro@example.test": DESTINATARIO,
        "support@example.test": REMETENTE,
        REMETENTE: REMETENTE,
        DESTINATARIO: DESTINATARIO,
    }
    mensagens = {}
    with smtplib.SMTP(SERVIDOR_CATCH_ALL, 25, local_hostname="origem.example.test", timeout=10) as smtp:
        smtp.starttls(context=contexto)
        for destinatario in rotas:
            mensagem = montar_mensagem(remetente, destinatario)
            # O envelope vazio dispensa DNS para o remetente sintético.
            smtp.send_message(mensagem, from_addr="")
            mensagens[destinatario] = mensagem["Message-ID"]

    with ExitStack() as conexoes:
        caixas = {}
        for caixa in (REMETENTE, DESTINATARIO):
            imap = conexoes.enter_context(
                imaplib.IMAP4_SSL(SERVIDOR_CATCH_ALL, 993, ssl_context=contexto, timeout=10)
            )
            imap.login(caixa, senha)
            caixas[caixa] = imap

        for destinatario, id_mensagem in mensagens.items():
            destino = rotas[destinatario]
            conferir_mensagem(caixas[destino], id_mensagem, remetente, destinatario)

        for destinatario, id_mensagem in mensagens.items():
            destino = rotas[destinatario]
            outra_caixa = REMETENTE if destino == DESTINATARIO else DESTINATARIO
            if buscar_uids(caixas[outra_caixa], id_mensagem):
                raise SystemExit(f"Mensagem para {destinatario} também apareceu em {outra_caixa}")
            print(f"{destinatario} entregue em {destino} com conteúdo conferido")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subcomandos = parser.add_subparsers(dest="acao", required=True)
    subcomandos.add_parser("enviar")
    subcomandos.add_parser("catch-all")
    verificar = subcomandos.add_parser("conferir")
    verificar.add_argument("id_mensagem")
    args = parser.parse_args()

    contexto = ssl.create_default_context(cafile=str(CERTIFICADO))
    if args.acao == "enviar":
        enviar(contexto)
    elif args.acao == "conferir":
        conferir(contexto, args.id_mensagem)
    else:
        ensaiar_catch_all(contexto)


if __name__ == "__main__":
    main()
