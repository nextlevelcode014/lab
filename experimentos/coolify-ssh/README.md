# Coolify por SSH, sem Tailscale

Ensaio da configuração de um servidor Ubuntu **24.04** com Ansible e acesso
SSH comum. A Hetzner fornece apenas a VPS descartável do projeto **lab**;
a instalação não depende da API dela nem de Tailscale. O objetivo é testar
o procedimento antes de adaptá-lo ao servidor do trabalho.

O Terraform cria a VPS, o firewall e o inventário. O cloud-init cria o
usuário `lab`, com sudo, e uma identificação do experimento. O Ansible
instala o Coolify **4.4.7**, configura as portas e verifica o resultado.
Os playbooks exigem a identificação do lab; não os aponte ao trabalho.
A role `ansible/roles/coolify` concentra a configuração que poderá ser
copiada e revisada no repositório do trabalho, após o ensaio.

O experimento anterior, [coolify-hetzner](../coolify-hetzner/README.md),
permanece independente, com outro state e acesso pela Tailscale.

## Acesso e isolamento

| Serviço | Acesso |
|---|---|
| SSH, 22/tcp | IPs dos administradores, declarados no tfvars |
| Painel, 8000/tcp | `127.0.0.1` no servidor, pelo túnel SSH |
| Realtime e terminal, 6001/6002/tcp | `127.0.0.1` no servidor, pelo mesmo túnel |
| Sites, 80/443/tcp | Internet, pelo proxy do Coolify |
| Banco de um app | Rede Docker; sem publicar a porta do banco |

O firewall da Hetzner já acompanha o servidor na criação. Além dele, o
`docker-compose.custom.yml` restringe as três portas administrativas ao
loopback, **antes** de o instalador subir os containers. `!override`
substitui a lista de portas, evitando manter os bindings públicos do
Compose original. Esse arquivo é incluído pelo instalador oficial.
Não basta colocar o painel atrás do UFW: portas publicadas pelo Docker
podem passar por fora dele.

Não preencha o **Domain da instância** no Coolify: isso publicaria o painel
pelo proxy em 80/443. Os domínios das aplicações são independentes e podem
ser públicos. Não crie proxy ou mapeamento público para as portas de administração.

## Pré-requisitos e custo

- Projeto **lab** da Hetzner e token exclusivo de leitura/escrita;
  [isolamento e cobrança](../../docs/nuvem.md#hetzner).
- Chave SSH já existente; copie somente a pública para o tfvars.
- Terraform, Ansible e a coleção `cloud.terraform` disponíveis localmente.
  Instalar dependências exige autorização; o `init` baixa os providers do lock.
- Saída da VPS para os repositórios Ubuntu/Docker, o CDN do Coolify,
  registros de imagens, Git e a autoridade de certificados.
- Servidor novo: a role recusa Coolify não gerenciado por ela, containers
  existentes e serviços nas portas 80/443 no primeiro uso.

O padrão é `cx23` em `fsn1`, Ubuntu 24.04. Confira na console o preço da
VPS e do IPv4 antes de provisionar, defina um teto e deixe um alerta ativo.
Um lembrete local de duas horas pode ser criado **na sua máquina Linux**:

```bash
systemd-run --user --unit=lab-coolify-ssh-custo --on-active=2h /usr/bin/notify-send 'Custo do lab' 'Revise a VPS coolify-ssh na Hetzner e destrua se o ensaio terminou.'
systemctl --user list-timers lab-coolify-ssh-custo.timer
```

Confira que o timer aparece com a próxima execução. É um aviso, não um
limite de gasto, e depende de a máquina estar ligada. O Terraform não cria
esse lembrete porque ele pertence à máquina do responsável e deve existir
antes do primeiro `apply`. A cobrança só termina ao apagar os recursos.

## 1. Preparar e criar a VPS

Na raiz do repositório, entre no root Terraform deste experimento:

```bash
cd experimentos/coolify-ssh/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edite o arquivo ignorado pelo Git com o token do projeto **lab**, a chave
pública e seu IP público de saída em `ssh_source_cidrs` (`/32` para IPv4,
`/128` para IPv6). Não reutilize as credenciais de produção.

O backend é **local** e o state pertence só a este diretório. Depois de
autorizados o download dos providers e o provisionamento desta revisão:

```bash
terraform init
terraform plan
terraform apply
terraform output
```

Confira no plano: apenas `hcloud_server.coolify`, `hcloud_firewall.coolify`,
`hcloud_ssh_key.lab` e `ansible_host.coolify`; servidor e recursos que
aceitam labels com `env=lab`. Confira na console que o servidor pertence ao
projeto **lab** e usa Ubuntu 24.04. O fluxo normal é merge antes de aplicar;
aplicar a branch exige autorização explícita para o SHA testado.

Se seu IP de saída mudar, atualize `ssh_source_cidrs`, confira o plano e
aplique a regra antes de reconectar. Em caso de bloqueio, use a console da
Hetzner para diagnóstico; não abra a 22 para toda a internet.

## 2. Abrir o túnel antes de instalar

No mesmo diretório `terraform/`:

```bash
terraform output -raw tunel
```

Execute o comando impresso em um terminal separado e deixe-o aberto. O
formato é este, substituindo `<IP>` pelo output `ipv4`:

```bash
ssh -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 \
  -L 127.0.0.1:8000:127.0.0.1:8000 \
  -L 127.0.0.1:6001:127.0.0.1:6001 \
  -L 127.0.0.1:6002:127.0.0.1:6002 lab@<IP>
```

É esperado que o SSH fique aberto sem imprimir nada. As portas locais
precisam estar livres. Só depois da instalação o painel responderá em
`http://127.0.0.1:8000`; as outras duas portas mantêm realtime e terminal.

## 3. Configurar com Ansible

Em outro terminal, rode de dentro de `ansible/`:

```bash
cd experimentos/coolify-ssh/ansible
ansible-playbook playbook.yml --list-hosts
```

Confira que aparece **somente** `lab-coolify-ssh` (ou o sufixo escolhido no
tfvars), com o IP da VPS nova no inventário. O inventário `cloud.terraform`
lê apenas `../terraform`. Após autorização da execução remota:

```bash
ansible-playbook playbook.yml
```

O playbook espera o cloud-init, exige Ubuntu 24.04 e sudo/root, prepara o
override e executa o instalador oficial com versão e checksum fixados. O
instalador instala Docker e dependências, configura o daemon, cria os dados
em `/data/coolify` e autoriza a chave SSH do Coolify para administrar o host.
Não há vault ou segredo de Tailscale neste ensaio. Atualizações automáticas
ficam desativadas para preservar a versão testada.

O checksum fixa o instalador revisado, não todos os downloads que ele faz:
Compose, helper, pacotes e imagens auxiliares continuam vindo dos serviços
oficiais. Se o checksum do instalador mudar, pare e revise o script em PR;
não desative a verificação para fazê-lo passar. Uma mudança de versão
também é recusada nesta role: upgrade é outra operação.

Ao terminar, abra `http://127.0.0.1:8000` e **crie o admin imediatamente**.
O primeiro cadastro tem privilégios de administração; a janela inicial é
de dez minutos. Esse cadastro é manual para o responsável escolher e
guardar sua senha sem colocá-la no repositório. Se a janela fechar, o
procedimento oficial pede reiniciar somente o container `coolify`; isso
também exige autorização de execução remota:

```bash
ssh lab@<IP> sudo docker restart coolify
```

No painel: mantenha o **Domain da instância vazio**, ative 2FA e valide
**Servers → localhost**. O Coolify precisa conseguir entrar por SSH no
próprio host para fazer deploy, mesmo estando instalado nele.

## 4. Conferir instalação, privacidade e repetição

De `ansible/`, após autorização de leitura remota:

```bash
ansible-playbook verificar.yml
```

Ele verifica imagem na versão 4.4.7, container `healthy`, HTTP local 200,
atualização automática desligada, domínio da instância vazio e os bindings
exatos das três portas administrativas em `127.0.0.1`. Não imprime o
ambiente do container nem as senhas. Isso confere a configuração no host,
além do firewall da Hetzner; o check também recusa um painel publicado pelo proxy.

Da sua máquina, usando o IP público, confira que as três portas não abrem:

```bash
curl --connect-timeout 5 --max-time 5 http://<IP>:8000
curl --connect-timeout 5 --max-time 5 http://<IP>:6001
curl --connect-timeout 5 --max-time 5 http://<IP>:6002
```

É esperado timeout ou conexão recusada, enquanto o painel abre pelo túnel.
Confira também o realtime e o terminal no navegador. Após autorização,
rode `ansible-playbook playbook.yml` outra vez: o esperado é `failed=0` e
`changed=0`; o instalador não deve rodar de novo. Se a instalação falhar,
leia os logs em `/data/coolify/source/` antes de decidir entre repetir e
recriar a VPS. A marca de conclusão só é escrita após as verificações.

## 5. Ensaiar os caminhos de deploy

Comece com um recurso sem dados para separar falhas da plataforma das do
projeto. No Coolify, crie um projeto e um recurso **Docker Image** usando
`traefik/whoami:v1.11.0`, porta interna **80** e um domínio como
`https://app.<IP>.sslip.io`. Faça **Deploy**. Confira que a página abre de
fora da sua rede, com HTTPS válido; o `sslip.io` dispensa alterar o DNS do
trabalho. Ele é compartilhado e pode atingir limites do Let's Encrypt;
HTTP funcionando sozinho não aprova o teste de TLS.

Depois, faça um recurso **Docker Compose** com o conteúdo de
[`ansible/files/compose-teste.yml`](ansible/files/compose-teste.yml).
Configure um domínio para o serviço `web` na porta 80. O exemplo não tem
`ports`: quem publica o acesso é o proxy do Coolify. Confira a página e
faça um redeploy. Não publique portas de bancos ou da administração.

Para ensaiar **Git**, use um repositório de teste autorizado, com Dockerfile
ou Compose. Selecione o build pack correspondente e informe a porta interna
do app. Para repositório privado, cadastre uma deploy key de leitura no
provedor Git; o cadastro é manual porque exige acesso à conta do responsável.
Para imagem privada, configure a autenticação do registry sem versionar o
token. Esses acessos devem pertencer ao lab, sem credenciais do trabalho.
Confira clone/pull, build, healthcheck, HTTPS e redeploy com uma alteração
visível. Se o projeto tiver banco, ensaie também persistência e restauração
com dados fictícios antes de considerá-lo validado.

O painel privado **não recebe webhooks públicos**. O primeiro ensaio usa
Deploy pelo botão. Automação por CI precisará de um caminho próprio até a
API, por exemplo um túnel SSH autorizado no runner; ela não está configurada
por este experimento. O pipeline com Tailscale do cenário antigo não se
aplica aqui.

## 6. Guardar o mínimo para recuperação

Se precisar preservar a instância, na raiz deste experimento, antes de
destruir e após autorização de leitura dos segredos:

```bash
install -d -m 700 .private
umask 077
ssh lab@<IP> sudo cat /data/coolify/source/.env > .private/coolify.env
ssh lab@<IP> sudo docker exec coolify-db pg_dump -U coolify -d coolify -Fc > .private/coolify-db.dmp
test -s .private/coolify.env
test -s .private/coolify-db.dmp
```

Guarde os arquivos em armazenamento cifrado do responsável. O `.env`
contém o `APP_KEY`, necessário para decifrar segredos do dump. Os arquivos
locais são ignorados pelo Git. Esse procedimento não cobre os bancos e
volumes dos apps nem comprova uma restauração; a perda da VPS os apaga.
S3 e BorgBase não são provisionados neste cenário.

## 7. Destruir

Após autorização, no root Terraform **deste** experimento:

```bash
cd experimentos/coolify-ssh/terraform
terraform destroy
terraform state list
```

Confira state vazio e ausência do servidor, firewall e chave do experimento
na console do projeto lab. Nenhum recurso do cenário `coolify-hetzner` deve
aparecer no plano. Os dados da VPS são descartados com ela.

Feche o túnel com `Ctrl+C`. Se adicionou deploy key ou token de registry,
revogue-os no respectivo provedor: são externos ao Terraform. Se ainda
estiver pendente, cancele o lembrete local:

```bash
systemctl --user stop lab-coolify-ssh-custo.timer
```

Remova uma host key antiga somente depois de confirmar que a VPS foi
destruída e que o IP será reutilizado por uma máquina nova:

```bash
ssh-keygen -R <IP>
```

## Evidências e passagem para o trabalho

Registre no PR o SHA testado, comandos, versões, resultados e limites,
sem token, state ou dados privados. Os checks locais seguem
[`docs/verificacoes-locais.md`](../../docs/verificacoes-locais.md);
eles não substituem a execução na VPS.

Antes de adaptar a role ao trabalho, confira as instruções daquele
repositório, o usuário/sudo, serviços e containers existentes, portas livres,
recursos, DNS, registry e backup. O Ubuntu 24.04 e o túnel são premissas já
definidas; a ausência de serviços no servidor do trabalho ainda precisa ser
confirmada. Faça a mudança e a autorização de aplicação no contexto do
trabalho. O Terraform da Hetzner, as credenciais e o inventário do lab ficam
aqui.

Referências oficiais: [instalação](https://coolify.io/docs/start-with-self-hosted),
[firewall e override](https://coolify.io/docs/core/infrastructure/servers/firewall),
[correções da versão 4.4.7](https://coolify.io/docs/knowledge-base/php-security-advisory-2026).
