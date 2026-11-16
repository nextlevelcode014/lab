"""Envia uma mensagem pelo SMTP e localiza o mesmo conteúdo na caixa IMAP."""
import argparse
from email import policy
from email.message import EmailMessage
from email.parser import BytesParser
from email.utils import make_msgid
from getpass import getpass
import imaplib
from pathlib import Path
import smtplib
import ssl
import time

SERVIDOR = "172.30.85.2"
REMETENTE = "ana@example.test"
DESTINATARIO = "bruno@example.test"
CORPO = "Mensagem de teste do Docker Mailserver no lab."
CERTIFICADO = Path(__file__).resolve().parent / "dados/tls/mail.crt"


def enviar(contexto):
    mensagem = EmailMessage()
    mensagem["From"] = REMETENTE
    mensagem["To"] = DESTINATARIO
    mensagem["Subject"] = "Ensaio de entrega local"
    mensagem["Message-ID"] = make_msgid(domain="example.test")
    mensagem.set_content(CORPO)

    senha = getpass(f"Senha de {REMETENTE}: ")
    with smtplib.SMTP(SERVIDOR, 587, local_hostname="cliente.example.test", timeout=10) as smtp:
        smtp.starttls(context=contexto)
        smtp.login(REMETENTE, senha)
        smtp.send_message(mensagem)
    print(mensagem["Message-ID"])


def conferir(contexto, id_mensagem):
    senha = getpass(f"Senha de {DESTINATARIO}: ")
    with imaplib.IMAP4_SSL(SERVIDOR, 993, ssl_context=contexto, timeout=10) as imap:
        imap.login(DESTINATARIO, senha)
        limite = time.monotonic() + 30
        while True:
            imap.select("INBOX", readonly=True)
            status, dados = imap.uid("search", None, "HEADER", "Message-ID", id_mensagem)
            if status == "OK" and dados[0]:
                break
            if time.monotonic() >= limite:
                raise SystemExit(f"Mensagem {id_mensagem} ausente na caixa após 30 s")
            time.sleep(1)

        for uid in dados[0].split():
            status, partes = imap.uid("fetch", uid, "(BODY.PEEK[])")
            if status != "OK":
                raise SystemExit(f"Não foi possível ler a mensagem com UID {uid!r}")
            for parte in partes:
                if isinstance(parte, tuple):
                    mensagem = BytesParser(policy=policy.default).parsebytes(parte[1])
                    if (
                        mensagem["Message-ID"] == id_mensagem
                        and mensagem["From"] == REMETENTE
                        and mensagem["To"] == DESTINATARIO
                        and mensagem.get_content().strip() == CORPO
                    ):
                        print(f"Mensagem {id_mensagem} confirmada na caixa de {DESTINATARIO}")
                        return
        raise SystemExit(f"Conteúdo inesperado para {id_mensagem}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subcomandos = parser.add_subparsers(dest="acao", required=True)
    subcomandos.add_parser("enviar")
    verificar = subcomandos.add_parser("conferir")
    verificar.add_argument("id_mensagem")
    args = parser.parse_args()

    contexto = ssl.create_default_context(cafile=str(CERTIFICADO))
    if args.acao == "enviar":
        enviar(contexto)
    else:
        conferir(contexto, args.id_mensagem)


if __name__ == "__main__":
    main()
