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

Voluntarily declared income, rises with increasing individual income, penalty rate, and audit probability, and decreases with while increasing the tax rate as proposed in the neoclassical theory of evasion by Allingham and Sandmo (1972), an also includes Exponential utility and public goods provision described by Hokamp (2014). The distribution of production among employers follows a power law in which there is a marked inequality in the distribution, characterized by a small percentage of people holding most resources (Chakraborti & Patriarca, 2008) this characterizes a capitalist economy like in Mexico. Mortality of employers follows a Weibull distribution (Pinder, Wiener & Smith, 1978). This function is adjusted for the case of Mexico, where life expectancy at birth is seventy-five years (CONAPO, 2020).

##### Emergence

The extension of tax evasion is an emerging result of the adaptive behavior of employers. These results are expected to vary in complex ways when the characteristics of individuals or their environment change. Other outcomes, such as the distribution of production and age, are more strictly imposed by rules and therefore less dependent on what individuals do. However, these results are important for the validation of the model.

##### Adaptation

Employers can change their alignment in the formal sector. To make that decision, they query a previously trained machine learning model. With this trait, agents could become full evaders, and therefore avoid paying taxes. The tax authority does not have adaptation mechanisms.

##### Objectives

The employer's goal is to increase his utility by paying the least amount of taxes. The objective of the tax authority is to increase tax collection.

##### Learning

The adaptive trait of employers can change with changes in their internal and environmental states. To do this, employers perform a query to a previously trained ML model, which includes data on labor market conditions and the perceived quality of public security and corruption.

##### Prediction

The employers' learning is an off-line process. During the simulation, employers sense their current conditions and act accordingly. Employers do not have an internal model to estimate their future conditions or the consequences of their decision.

##### Sensing

Employers consider size of their company, education, sector of occupation, state, size of the locality, age, and income as internal states, and they perceive tax rate, and level of insecurity as environmental variables. If an audit is successful, the tax authority can collect undeclared tax from employers.

##### Interaction

Interactions between employers and the tax authority are direct, when with a certain probability an audit is carried out.

##### Stochasticity

The audit process is assumed random, both the probability of carrying it out and its probability of success follow a uniform distribution. The process of initialization of the employers' income is also considered random, following a power law. The probability of death of employers is also random following a Weibull survival distribution. In the first process, stochasticity is used to make events occur with a specific frequency. In the last two processes, stochasticity is used to reproduce the variability in processes for which it is not important to model the real causes of the variability.

##### Collectives

Employers are grouped into three types of tax behavior, full evaders, partial evaders, and full taxpayers. This collective is a definition of the model in which the set of the employers with certain properties about the amount of taxes paid are defined as a separate kind of employer with its own variables and traits.

##### Observation

At the end of each run, data is collected on the extent of tax evasion, the amount of tax collected, and the number of full evader employers.

#### Details

##### Initialization

##### Input data

##### Submodels

### References

-    J. Alm, (2011). «Measuring, explaining, and controlling tax evasion: lessons from theory, experiments, and field studies,» *International Tax and Public Finance*, pp. 54-77.
-    S. Hokamp, (2014). «Dynamics of tax evasion with back auditing, social norm updating, and public goods provision - An agent-based simulation,» *Journal of Economic Psychology,* pp. 187-199.
-    M. G. Allingham y A. Sandmo, (1972). «Income tax evasion: a theoretical analysis,» *Journal of Public Economics,* pp. 323-338.
-   V. Grimm, U. Berger, D. L. DeAngelis, J. G. Polhill, J. Giske y S. F. Railsback, (2010). «The ODD protocol: A review and first update,» *Ecological Modelling,* pp. 2760-2768.
-   A. Chakraborti & M. Patriarca, (2008). «Gamma-distribution and wealth inequality,» *Journal of physics,* pp. 233-243.
-   J. E. Pinder, J. G. Wiener y M. H. Smith, (1978). «The Weibull Distribution: A New Method of Summarizing Survivorship Data,» *Ecology,* pp. 175-179.
-   CONAPO, (2020). «Datos Abiertos. Indicadores demográficos 1950 - 2050.,» Consejo Nacional de Población, Ciudad de México.
