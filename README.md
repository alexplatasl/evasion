## An agent-based simulation assisted by machine learning for the analysis of payroll tax evasion

Alejandro Platas-López & Alejandro Guerra-Hernández

### Introduction

Tax evasion is an illegal and intentional activity taken by individuals to reduce their legally due tax obligations (Alm, 2011). With the large amount of data available in the National Institute of Statistics and Geography, this model introduces an agent-based model and simulation linked to a machine-learning model for the analysis of payroll tax evasion, a kind of tax that employers must paid on the wages and salaries of employees.

Each state has autonomy over the way in which the payroll tax is collected. Therefore, to model these different fiscal scenarios and their effects, an explicit representation of the space is made through a Geographic Information System with hexagonal tessellation. The effects of quality in the provision of public goods, on tax compliance are also explored.

A priori, a random forest model is obtained from the National Survey of Occupation and Employment and the National Survey of Quality and Government Impact. At the beginning of simulation employer agents in the model get some properties directly from the data set and use the learned model to derive some others during the simulation. Within the framework presented by Hokamp (2014), novel insights into payroll tax compliance driven by the quality of public goods provision, and social norms are presented.

Taxpayers rely on Allingham and Sandmo's expected utility maximization (Allingham & Sandmo, 1972). So, in each period, the decision on the amount to be declared made by the employers, is the one that maximizes their utility. The model is defined following the ODD (Overview, Design concepts, and Details) Protocol and implemented in NetLogo. Since this approach capture complex real-world phenomena more realistically, the model is promoted as a toolbox for studying fiscal and public policy implications in tax collection. It was found that the perception of the quality of the goods provided by the state has a significant effect on the collection of taxes. Finally, our sensitivity analysis provides numerical estimates that reveal the strong impact of the penalty and tax rate on tax evasion.

### Configuration

#### R

Install the following R packages from CRAN, just run

``` {.r}
install.packages("rJava")
install.packages("ranger")
install.packages("readr")
```

#### Netlogo

Configure the R extention appropriately.

### ODD protocol

For the sake of reproducibility, the details of the model will be described following the ODD protocol (Grimm et al., 2010), which is organized in three parts:

1.  Overview. A general description of the model, including its purpose and its basic components: agents, variables describing them and the environment, and scales used in the model, e.g., time and space; as well as a processes overview and their scheduling.

2.  Design concepts. A brief description of the basic principles underlying the model's design, e.g., rationality, emergence, adaptation, learning, etc.

3.  Details. Full definitions of the involved submodels.

#### Overview

##### Purpose. 
Analyze the effect of institutional determinants on payroll tax evasion in Mexico.

##### Entities, state variables, and scales

-   Agents: Employers and tax authority.
-   Environment: A Mexican state-level representation of the payroll tax system.
-   Scales: Time is represented in discrete periods, each step representing a month, which corresponds to the tax collection period according to the current legislation. In order to have a margin of error less than 5% with a confidence interval of 99% in the selected sample, each employer agent in the model represents 2,000 employers in the 2019 Mexican labor market.
-   State variables: The attributes that characterize each agent are shown in Table 1.

| Agent    | Type    | Attributes                                                   |
| -------- | ------- | ------------------------------------------------------------ |
| Auditor  | `Agset` | employers-of-auditor                                         |
| Auditor  | `Float` | penalty-collected; tax-collected                             |
| Auditor  | `Int`   | ent-auditor                                                  |
| Employer | `Bool`  | audit?; audited?; formal-or-informal (mh_col)                |
| Employer | `Float` | corruption; declared-tax; insecurity; payroll; payroll*; prob-formal; production; risk-aversion-ρ; tax; undeclared-payroll; undeclared-tax; α-s; δ |
| Employer | `Int`   | eda (age); business-size (ambito2); education (anios_esc); economic-activity (c_ocu11c); state (ent); income (ing7c); size-of-region (t_loc); type-of-taxpayer |

**Table 1**: State variables by agent. In parentheses, the name of attribute in the INEGI dataset.

##### Process overview and scheduling

1.  Employers decide in which market to produce, formal or informal, querying a machine learning model.

2.  Informal employers are full evaders. Formal employers calculate the amount of taxes to report. If they calculate to report zero taxes, they also become full evaders. If they calculate to report all the tax, they become full taxpayers. In any other case, they become partial evaders.

3.  Tax authority collects the declared amount of taxes.

4.  The tax authority conducts audits on a random basis. If the audit is successful, then partial and full evaders must pay the evaded amount and a penalty for the undeclared amount.

5.  Every 12 months employers increase their age. With some probability, in each period, employers can die. If this happens, they are replaced by another employer with the same characteristics except for age.

#### Design concepts

##### Basic Principles

##### Emergence

##### Adaptation

##### Objectives

##### Learning

##### Prediction

##### Sensing

##### Interaction

##### Stochasticity

##### Collectives

##### Observation

#### Details

##### Initialization

##### Input data

##### Submodels

### References

-    J. Alm, (2011). «Measuring, explaining, and controlling tax evasion: lessons from theory, experiments, and field studies,» *International Tax and Public Finance*, pp. 54-77.
-    S. Hokamp, (2014). «Dynamics of tax evasion with back auditing, social norm updating, and public goods provision - An agent-based simulation,» *Journal of Economic Psychology,* pp. 187-199.
-    M. G. Allingham y A. Sandmo, (1972). «Income tax evasion: a theoretical analysis,» *Journal of Public Economics,* pp. 323-338.
-   V. Grimm, U. Berger, D. L. DeAngelis, J. G. Polhill, J. Giske y S. F. Railsback, (2010). «The ODD protocol: A review and first update,» *Ecological Modelling,* pp. 2760-2768.
