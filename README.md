# SchemaCompass 🧭

<a href="https://www.buymeacoffee.com/leonardocx" target="_blank">
  <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me a Coffee" style="height: 60px !important;width: 217px !important;">
</a>

**SchemaCompass: A Bússola de IA para navegar, entender e documentar a complexidade de qualquer esquema de banco de dados.**

## O Problema

Bancos de dados em sistemas reais estão em constante evolução, tornando a documentação manual um processo caro, demorado e quase sempre desatualizado. Desenvolvedores perdem horas preciosas tentando decifrar a estrutura, as regras de negócio e as dependências entre tabelas, o que resulta em uma curva de aprendizado lenta e um maior risco de erros.

## A Solução: SchemaCompass

O **SchemaCompass** é uma ferramenta de engenharia de dados que resolve este problema de forma inovadora. Utilizando o poder de Modelos de Linguagem Grandes (LLMs), ele se conecta a um banco de dados MySQL, analisa sua estrutura a um nível profundo e gera um **mapa semântico** em formato JSONL.

Este mapa não é apenas uma lista de tabelas e colunas; é um documento vivo, enriquecido por IA, que descreve o propósito de cada elemento do banco de dados, identifica campos obrigatórios e detalha os relacionamentos entre as tabelas.

## ✨ Principais Funcionalidades

* **Mapeamento Automático:** Conecta-se a um banco de dados MySQL e extrai todos os metadados do `INFORMATION_SCHEMA`.
* **Enriquecimento com IA:** Utiliza um LLM (como os da família Gemini ou modelos locais via Ollama) para gerar descrições claras e úteis para cada tabela e cada campo.
* **Análise de Dependências:** Identifica e documenta explicitamente todas as chaves estrangeiras (foreign keys), mostrando como as tabelas se relacionam.
* **Saída Estruturada:** Gera um arquivo `.jsonl` limpo e bem estruturado, pronto para ser consumido por outras ferramentas ou para análise humana.

## 📐 Arquitetura e Conceito

O poder do SchemaCompass não reside apenas no código, mas na arquitetura de como a informação é processada. A abordagem se baseia em três pilares principais:

1.  **Mapeamento Semântico vs. Estrutural:** Diferente de ferramentas tradicionais que apenas extraem a estrutura, o SchemaCompass foca no *significado*. Ele utiliza um LLM para inferir o propósito de negócio de cada tabela e campo, criando um mapa semântico.
2.  **Enriquecimento Granular:** A IA é utilizada de forma cirúrgica, campo a campo, em um processo de enriquecimento. Isso garante descrições contextuais e de alta qualidade, uma abordagem que chamamos de "Lógica Zero na IA", onde o controle do fluxo permanece no código e a IA é usada para tarefas de criatividade focada.
3.  **O Mapa como DNA:** O arquivo `.jsonl` resultante não é o fim, mas o começo. Ele é projetado para ser o "DNA" ou a "Constituição" para sistemas de IA de nível superior, como assistentes conversacionais e ferramentas de migração, que podem ler este mapa para entender e operar sobre o banco de dados de forma autônoma.

## 🚀 Como Usar

1.  **Clone o repositório:**
    ```bash
    git clone [https://github.com/leonardocxavier/SchemaCompass.git](https://github.com/leonardocxavier/SchemaCompass.git)
    cd SchemaCompass
    ```

2.  **Configure o Script:**
    Abra o arquivo `seu_script.sh` e configure as variáveis de conexão com o seu banco de dados MySQL (`MYSQL_DB`) e o modelo de LLM que deseja usar (`OLLAMA_MODEL`).

3.  **Execute:**
    Dê permissão de execução ao script e rode-o:
    ```bash
    chmod +x SchemaCompass.sh
    ./SchemaCompass.sh
    ```
    O mapa será gerado no arquivo `mapa_producao.jsonl`.

## 📄 Exemplo de Saída

Aqui está um exemplo da estrutura gerada a partir de um banco de dados de demonstração:

```json
{
  "Tabela": "posts",
  "label": "Posts do Blog",
  "descricao": "Armazena o conteúdo principal dos artigos e páginas do blog.",
  "tipo": "transacional",
  "campos_obrigatorios": [
    "id_post",
    "id_autor",
    "titulo",
    "status"
  ],
  "campos": [
    {
      "nome": "id_post",
      "tipo_dado": "int",
      "obrigatorio": true,
      "descricao": "Identificador único para cada postagem.",
      "relacionamento": null
    },
    {
      "nome": "id_autor",
      "tipo_dado": "int",
      "obrigatorio": true,
      "descricao": "Referencia o autor do post na tabela 'autores'.",
      "relacionamento": {
        "tabela": "autores",
        "campo": "id_autor"
      }
    }
  ],
  "dependencias": [
    {
      "campo": "id_autor",
      "aponta_para": "autores.id_autor"
    }
  ]
}
```

## 🗺️ Roadmap e Visão de Futuro
O SchemaCompass nasceu como um protótipo em Bash para validar uma ideia poderosa. O plano é evoluir esta prova de conceito para uma suíte de ferramentas robusta e multi-linguagem.

## 📌 Roadmap v0.1 (Bash) - Prova de Conceito (Status: Concluído ✅)

Script funcional para extrair e mapear esquemas MySQL.
Validação da arquitetura de enriquecimento com LLMs (Ollama/Gemini).
Geração de um mapa semântico detalhado em formato .jsonl.

## 📌 Roadmap v1.0 (Python) - Ferramenta CLI Profissional (Próximo Passo ➡️)

Reescrever o core em Python para robustez e escalabilidade.
Adicionar suporte a múltiplos bancos de dados (PostgreSQL, SQL Server, etc.).
Implementar chamadas de API paralelas para um mapeamento de alta velocidade.
Distribuir como um pacote instalável via pip.

## 📌 Roadmap v2.0 e Além - A Plataforma de Inteligência de Dados (A Visão 💡)

Assistente Conversacional: Utilizar o mapa gerado para alimentar um chatbot capaz de guiar usuários em tarefas complexas de forma humanizada, eliminando formulários tradicionais.
Ferramenta de Migração Inteligente: Sistemas que usam o mapa para automatizar e validar migrações de dados complexas.
Módulo de Saúde da Infraestrutura: Uma plataforma que aprende o comportamento "normal" de seus servidores e prevê falhas de hardware iminentes, transformando a manutenção reativa em uma operação proativa e evitando downtime.

## 📖 Histórico do Projeto
O SchemaCompass nasceu em junho de 2025 da necessidade prática de documentar um complexo sistema de software imobiliário. A prova de conceito inicial foi desenvolvida em Bash para demonstrar rapidamente a viabilidade da arquitetura de mapeamento semântico com LLMs locais, evoluindo para a visão de uma plataforma completa de inteligência de dados.

## 🤝 Contribuições
Este é um projeto de código aberto e contribuições são bem-vindas! Se você tem ideias para melhorias ou encontrou algum bug, por favor, abra uma "Issue" ou envie um "Pull Request".

## ✍️ Como Citar
Se você utilizar a arquitetura, o conceito ou o código do SchemaCompass em seu trabalho, por favor, cite este repositório. Agradecemos o reconhecimento da comunidade!

## 📜 Licença
Este projeto está sob a Licença MIT. Veja o arquivo LICENSE para mais detalhes.


