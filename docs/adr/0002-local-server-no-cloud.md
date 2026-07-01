# Local server in the store, no cloud, no internet access

O app roda em um servidor local (PC ou mini-PC) dentro do mercadinho, e os dispositivos (celular, tablet, navegador no escritório) acessam pela rede Wi-Fi da loja. Não há dependência de serviços de nuvem (Firebase, Supabase, servidor público). Não há acesso de fora da loja — quando o dono sai, ele não usa o app.

**Por que essa escolha:** o usuário quer controle total sobre os dados financeiros do negócio, não quer lidar com custo recorrente de cloud, e a operação dele é geograficamente restrita à loja. A disponibilidade de internet na loja não é garantida (e ele não quer depender dela).

**Consequência prática:** o usuário vira responsável pelo servidor — manter a máquina ligada, fazer backup do banco (SQLite, copiado para um HD externo com periodicidade definida), garantir que o Wi-Fi alcance o(s) dispositivo(s) que ele usa, e atualizar o app manualmente. A escolha tecnológica concreta (hardware, sistema operacional, processo de instalação) está documentada no `README.md` operacional, não aqui.

**Consequência arquitetural:** o backend precisa rodar em hardware commodity (provavelmente um x86 com Windows ou Linux, possivelmente um Raspberry Pi). Não escolhemos nenhuma tecnologia que exija cloud no caminho crítico (ex.: autenticação via OAuth de terceiros, push notifications, etc.).
