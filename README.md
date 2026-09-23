<div align="center">
<img src="assets/header.png" alt="Akpedia project header" width="100%" />
</div>

## Introduction

This project was developed by **STEAM DUCKS**, a team of students from the 6th semester of the **Database program at FATEC São José dos Campos**.

The proposal is to build **Akpedia**, an **automated technical document classification** solution, developed in partnership with **Akaer**.

### Akaer: Industry Partner

**Akaer** is a Brazilian engineering company headquartered in São José dos Campos, operating in the **aeronautics, space, and defense** sectors, with strong expertise in structural design, product engineering, and the integration of highly complex systems.

In operations of this scale, the volume of **technical documentation** used across the life cycle of a program is significant, and organizing that collection directly impacts productivity, compliance, and the preservation of engineering knowledge.

<br>

> Automated technical document classification;  
> Metadata extraction and normalization;  
> Information search and retrieval;  
> Human curation and taxonomy evolution.

## Business Questions

The solution is expected to answer questions such as:

- Which category does each technical document belong to?

## Delivery Schedule

| Phase | Start | Delivery |
|---|---|---|
| General kick-off | 2026-08-24 | 2026-08-28 |
| Product Backlog building / Planning | 2026-08-31 | 2026-09-04 |
| Sprint 1 | 2026-09-07 | 2026-09-27 |
| Sprint Review / Planning | 2026-09-28 | 2026-10-02 |
| Sprint 2 | 2026-10-05 | 2026-10-25 |
| Sprint Review / Planning | 2026-10-26 | 2026-10-30 |
| Sprint 3 | 2026-11-02 | 2026-11-22 |
| Sprint Review | 2026-11-23 | 2026-11-27 |
| Solutions Fair | 2026-12-03 | 2026-12-03 |

## Epic Summaries

### Epic 1 — Validate the Best Way to Search Documents (Sprint 1: Sep 07 – Sep 27)

Before connecting real Akaer documents, we must verify that our search interface effectively solves engineers' needs: finding documents by typing a word, phrase, or question in one centralized location. This sprint delivers a home screen with centralized search, tested against a sample dataset (e.g., Kaggle) to validate core mechanics with low risk.

**Scope:**
- Simple home screen focusing on search
- Keyword, phrase, or natural question search over sample documents
- Clear display of search results

### Epic 2 — Smart Search with Real Documents (Sprint 2: Oct 05 – Oct 25)

With search mechanics validated, this sprint connects the system to Akaer's actual document repository. Engineers can upload new documents, while approvers receive AI-driven category suggestions to speed up reviews. Search capability expands to analyze internal document text alongside titles.

**Scope:**
- Standard user file upload area
- Automated category suggestion for uploads
- Approver pending review queue
- Approval interface with editing capabilities
- Status tracking for uploaders
- Full-text document content indexing and category filtering

### Epic 3 — Secure and Department-Tailored Access (Sprint 3: Nov 02 – Nov 22)

To protect sensitive data and provide relevant search experiences, this sprint introduces authenticated access, restricting document visibility based on department and role without compromising search simplicity.

**Scope:**
- User registration and login
- Data privacy consent at sign-up
- Three access levels (User, Approver, Admin)
- Role/department-based document visibility
- Administrative management area

## Product Backlog

Priority aligns with sprint progression: **High** validates search usability, **Medium** connects real document databases via AI support, and **Low** enforces secure, department-based access control (placed last as it depends on the first two working properly). [Access our full documentation.](https://thesteamducks.atlassian.net/wiki/external/YzdlN2UzNzhmNjNjNDJlZmFkZmJhNzFjMzM4M2NhYTE)

| Priority | Sprint | Epic   | ID     | User Story                                                         | Role                        |
|----------|--------|--------|--------|-----------------------------------------------------------------------|------------------------------|
| High     | 1      | Epic 1 | US 1.1 | Search documents in a single place as soon as I open the system       | Standard User     |
| High     | 1      | Epic 1 | US 1.2 | Quickly determine which search result is correct                      | Standard User     |
| Medium   | 2      | Epic 2 | US 2.1 | Avoid reading an entire document to determine its category            | Approver                     |
| Medium   | 2      | Epic 2 | US 2.2 | View everything pending my review in one place                        | Approver                     |
| Medium   | 2      | Epic 2 | US 2.3 | Approve documents with confidence, ensuring a reliable database       | Approver                     |
| Medium   | 2      | Epic 2 | US 2.4 | Share a new document with my colleagues                               | Standard User     |
| Medium   | 2      | Epic 2 | US 2.5 | Know whether my uploaded document is available to colleagues          | Standard User     |
| Medium   | 2      | Epic 2 | US 2.6 | Refine my search to find exactly what I need                          | Standard User     |
| Low      | 3      | Epic 3 | US 3.1 | Ensure sensitive department documents remain protected                | All Roles (Employee)         |
| Low      | 3      | Epic 3 | US 3.2 | Maintain company compliance regarding employee access data            | Administrator                |
| Low      | 3      | Epic 3 | US 3.3 | Define permissions for each employee in the system                    | Administrator                |
| Low      | 3      | Epic 3 | US 3.4 | View only documents relevant and permitted for my department          | Standard User     |
| Low      | 3      | Epic 3 | US 3.5 | Keep department structures and user details updated                   | Administrator                |

## Tech Stack

<p align="center">
  <a href="https://skillicons.dev">
    <img src="https://skillicons.dev/icons?i=python,vue,ts,docker,git,github,githubactions,vscode&theme=light" />
  </a>
</p>

## Contributors

Name | Role | Networking | Profile
--- | --- | --- | ---
Carlos Daniel | Dev Team | <a href="https://github.com/darloscaniel"><img src="https://img.shields.io/badge/GitHub-100000?style=for-the-badge&logo=github&logoColor=white" alt="GitHub"></a> <a href="https://www.linkedin.com/in/carlos-daniel-9516952b4"><img src="https://img.shields.io/badge/linkedin-%230077B5.svg?&style=for-the-badge&logo=linkedin&logoColor=white" alt="LinkedIn"></a> | <img src="https://github.com/darloscaniel.png" width="60"> |
Felipe Reis | Scrum Master | <a href="https://github.com/felpzreiz"><img src="https://img.shields.io/badge/GitHub-100000?style=for-the-badge&logo=github&logoColor=white" alt="GitHub"></a> <a href="https://www.linkedin.com/in/felipe-reiss/"><img src="https://img.shields.io/badge/linkedin-%230077B5.svg?&style=for-the-badge&logo=linkedin&logoColor=white" alt="LinkedIn"></a> | <img src="https://github.com/felpzreiz.png" width="60"> |
Mariana Oliveira | Dev Team | <a href="https://github.com/mariinetic"><img src="https://img.shields.io/badge/GitHub-100000?style=for-the-badge&logo=github&logoColor=white" alt="GitHub"></a> <a href="https://www.linkedin.com/in/oliveirasmari/"><img src="https://img.shields.io/badge/linkedin-%230077B5.svg?&style=for-the-badge&logo=linkedin&logoColor=white" alt="LinkedIn"></a> | <img src="https://github.com/mariinetic.png" width="60"> |
Rafaella Cruz | Product Owner | <a href="https://github.com/arafaellacruz"><img src="https://img.shields.io/badge/GitHub-100000?style=for-the-badge&logo=github&logoColor=white" alt="GitHub"></a> <a href="https://www.linkedin.com/in/rafaella-cruz"><img src="https://img.shields.io/badge/linkedin-%230077B5.svg?&style=for-the-badge&logo=linkedin&logoColor=white" alt="LinkedIn"></a> | <img src="https://github.com/arafaellacruz.png" width="60"> |
Matheus Marciano | Dev Team | <a href="https://github.com/MarcyLeite"><img src="https://img.shields.io/badge/GitHub-100000?style=for-the-badge&logo=github&logoColor=white" alt="GitHub"></a> <a href="https://www.linkedin.com/in/matheus-marciano-leite/"><img src="https://img.shields.io/badge/linkedin-%230077B5.svg?&style=for-the-badge&logo=linkedin&logoColor=white" alt="LinkedIn"></a> | <img src="https://github.com/MarcyLeite.png" width="60"> |

<div align="center">
<img src="assets/footer.png" alt="footer" width="100%" />
</div>