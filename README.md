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
| Employer | `Float` | corruption; declared-tax; insecurity; payroll; payroll*; prob-formal; production; risk-aversion-ρ; tax; undeclared-payroll; undeclared-tax; ![eqn-27](https://latex.codecogs.com/svg.image?\alpha_S); ![eqn-27](https://latex.codecogs.com/svg.image?\delta) |
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

Employers are initialized with data from official databases of Mexico, that is, the National Survey of Occupation and Employment (ENOE), the National Survey of Quality and Government Impact (ENCIG), as well as the tax laws of the different states where the payroll tax rate is specified. The period considered for the 3 sources of information is from 2011 to 2019.

ENOE is a quarterly survey, but just the third quarter is used as a reference for annual information. Among other data we can know different sociodemographic variables on the characteristics of the employers. From these variables, it can be determined whether an employer is in the formal or informal sector. After performing a pre-processing of the database including a manual selection and a recursive feature elimination with resampling algorithm, it was determined that the main variables that determine the employer's sector are size of the business (ambito2), education (anios_esc), economic activity (c_ocu11c), state (ent), size of region (t_loc), and age (eda). 

ENCIG is a biannual survey in which people are asked about the top 3 (three) problems they believe exist in their state. The main problems among all the states are insecurity, corruption, and unemployment. Insecurity and corruption are summarized by state and interpolated to get annual information. The resulting data is joined to the ENOE data set along with the tax data. 

The dataset collected in this way, gives a matrix of size ![eqn](https://latex.codecogs.com/svg.image?71833\times{10}), where the proportion of formal employers is 60.57%. A fast implementation of Random Forest was chosen to learn from data because it provides a fast model fitting and evaluating, is robust to outliers, can deal with simple linear and complicated nonlinear associations, and produces competitive prediction accuracy. To tune the hyperparameters and evaluate the performance of the model, a cross-validation with *10* folds was carried out. The final hyperparameters values were *mtry=20*, *ntrees=100*, and *nodesize = 1*. That setting gets an accuracy of 83.79%, which is considered good to avoid overfitting. The trained model will be available to employers during the simulation.

From the resulting preprocessed ENOE data a sampling is performed using the local pivot method, which effectively generates a balanced sample data set. Selected attributes to generate the balanced sample were the state, the employer's classification by belonging to the formal or informal sector, and the size of the employer's economic unit. This ensures that the employers in the model reflect the actual proportions of the Mexican labor market. The size of the selected sample corresponds to the scale 1 to 2000.
At time ![eqn](https://latex.codecogs.com/svg.image?t=0), of every simulation run, ![eqn](https://latex.codecogs.com/svg.image?N=1337) employers are initialized and distributed on each state according to the sample dataset. 32 auditors are also initialized representing each state tax authority. Some state variables are initialized by a submodel, either deterministic or random, while some others are based on data as shown in Table 2.

| Agent    | Initialization | Attributes                                                   |
| -------- | -------------- | ------------------------------------------------------------ |
| Auditor  | Deterministic  | penalty-collected; tax-collected                             |
| Auditor  | Random         | ent-auditor; my-employers                                    |
| Employer | Data base      | ambito2; anios_esc; c_ocu11c; corruption; eda; ent; ing7c; insecurity; mh_col; t_loc; tax |
| Employer | Deterministic  | audit?; audited?; declared-tax; payroll; payroll*; risk-aversion-ρ; type-of-taxpayer; undeclared-payroll; undeclared-tax; ![eqn-27](https://latex.codecogs.com/svg.image?\alpha_S); ![eqn-27](https://latex.codecogs.com/svg.image?\delta) |
| Employer | Random         | prob-formal; production                                      |

**Table 2**: Initialization of state variables.

In the same way, input parameters of simulation were adopted from literature, data base or through experimentation. Table 3 shows the initial values of the baseline model. The user interface also has other input parameters, one of them allows to switch “on” and “off” the machine learning model.

| Parameter                                                    | Description                                    | Value | Initialization  |
| ------------------------------------------------------------ | ---------------------------------------------- | ----- | --------------- |
| ![eqn-27](https://latex.codecogs.com/svg.image?\pi)          | Penalty rate                                   | 0.75  | Data base       |
| ![eqn-27](https://latex.codecogs.com/svg.image?\alpha)       | Audit probability                              | 0.05  | Experimentation |
| ![eqn-27](https://latex.codecogs.com/svg.image?\epsilon_{AP}) | Effectiveness of audit process                 | 0.75  | Experimentation |
| ![eqn-27](https://latex.codecogs.com/svg.image?\epsilon_{TC}) | Effectiveness of tax collection                | 0.7   | Literature      |
| ![eqn-27](https://latex.codecogs.com/svg.image?\Delta\theta) | Variation in tax rate                          | 0     | Data base       |
| ![eqn-27](https://latex.codecogs.com/svg.image?\Delta{PI})   | Variation in perceived insecurity              | 0     | Data base       |
| ![eqn-27](https://latex.codecogs.com/svg.image?\Delta{PC})   | Variation in perceived corruption              | 0     | Data base       |
| ![eqn-27](https://latex.codecogs.com/svg.image?\tau)         | Threshold for formal or informal sector choice | 0.5   | Literature      |

**Table 3**: Input parameter initialization of baseline model.

##### Input data

The model does not use input data to represent time-varying processes.

##### Submodels

1. A Geographical Information System layer is loaded. Each polygon is a hexagonal tessellation of the corresponding Mexican state.

2. ![eqn](https://latex.codecogs.com/svg.image?N=1337) employers are generated and initialized with information of the data base and moved to their corresponding state.

3. Auditors are generated and located to their assigned state.

4. The a priori learned random forest model is loaded.

5. Generate pareto-law values with the following distribution function

   ![eqn-5](https://latex.codecogs.com/svg.image?f(x)~x^{-1-\gamma})

6. Where ![eqn](https://latex.codecogs.com/svg.image?\gamma) is known as the Pareto exponent and estimated to be ![eqn](https://latex.codecogs.com/svg.image?\approx{3/2}) to characterize a capitalist economy.

7. ![eqn](https://latex.codecogs.com/svg.image?x\sim{N}(\mu,\sigma^2)) are the values generated by a normal distribution function with mean ![eqn](https://latex.codecogs.com/svg.image?\mu=2) and standard deviation ![eqn](https://latex.codecogs.com/svg.image?\sigma^2=0.2) for informal employers and ![eqn](https://latex.codecogs.com/svg.image?\sigma^2=0.3) for the formal ones.

8. To assign a fixed monthly production value to each employer. Generated power law values are multiplied by 23 in the case of informal employers and 50 for the formal. Those quantities generate a perfectly mixed Pareto distribution according to the basic principles and preserve the participation of the informal economy in Mexican GDP.

9. For simplicity, it is assumed that each employer allocates 30 percent of the value of production to payroll ![eqn](https://latex.codecogs.com/svg.image?W). The share of wages in Mexican GDP is between 30 and 40%.

10. At the beginning of the simulation, it is assumed that non-informal employers declare all the tax, declared payroll ![eqn-10](https://latex.codecogs.com/svg.image?W^{*}=W)

11. At the beginning declared tax ![eqn-10](https://latex.codecogs.com/svg.image?X^{*}) by each employer is equal to the declared payroll ![eqn-10](https://latex.codecogs.com/svg.image?W^{*}) multiplied by the tax rate ![eqn-10](https://latex.codecogs.com/svg.image?\theta) in their state.
12. Each 12 periods (months) employers increase their age, and they consult the learned model to decide whether to opt for the formal or informal market, taking their internal attributes and perceived insecurity as a reference.
13. Informal employers do not declare taxes.
14. By social norm, employers modify their risk aversion ![eqn-13](https://latex.codecogs.com/svg.image?\rho) according to their age as follows:

![eqn-14](./eqns/Eqn14.svg)

15. Let ![eqn-15](https://latex.codecogs.com/svg.image?\beta) the perceived public goods efficiency, and ![eqn-15](https://latex.codecogs.com/svg.image?\pi) the penalty rate.
16. Let ![eqn-16](https://latex.codecogs.com/svg.image?\epsilon_{AP}) and  ![eqn-16](https://latex.codecogs.com/svg.image?\epsilon_{TC}) the effectiveness of audit process and tax collection respectively.
17. Let ![eqn-17](https://latex.codecogs.com/svg.image?\alpha) the true audit probability and ![eqn-17](https://latex.codecogs.com/svg.image?\alpha_S) the subjective audit probability known to the employer.
18. Let ![eqn-18](https://latex.codecogs.com/svg.image?\delta=0.1), the updating parameter for ![eqn-18](https://latex.codecogs.com/svg.image?\alpha_S).
19. If an employer is audited in a specific period, subjective audit probability becomes ![eqn](https://latex.codecogs.com/svg.image?1).
20. In each period (if not audited again) ![eqn-20](https://latex.codecogs.com/svg.image?\alpha_S) decreases in ![eqn-20](https://latex.codecogs.com/svg.image?\delta) amount until ![eqn-20](https://latex.codecogs.com/svg.image?\alpha_S=\alpha).
21. Each period, employers calculate the amount of taxes to declare voluntarily ![eqn-21](https://latex.codecogs.com/svg.image?X^*), applying the expected utility maximization procedure adopted by Allingham and Sandmo (1972). Let lower bound:

![eqn-21](./eqns/Eqn21.svg)

22. And the upper bound:

![eqn-22](./eqns/Eqn22.svg)

23. If the subjective audit probability ![eqn-23](https://latex.codecogs.com/svg.image?\alpha_S) exceeds the upper limit in submodel 22, employer becomes fully tax compliant, that is, ![eqn-23](https://latex.codecogs.com/svg.image?X^{*}=W\theta), and when ![eqn-23](https://latex.codecogs.com/svg.image?\alpha_S) falls below the lower bound in submodel 21, the employer fully evades, that is ![eqn-23](https://latex.codecogs.com/svg.image?X^{*}=0).

24. For ![eqn-24](https://latex.codecogs.com/svg.image?\alpha_S) in the range for an inner solution, employer voluntarily declares:

    ![eqn-24](./eqns/Eqn24.svg)

25. The tax authority collects payroll taxes that employers voluntarily declared.

26. The tax authority carries out audits with a random probability of α and a level of effectiveness ![eqn-26](https://latex.codecogs.com/svg.image?\epsilon_{AP}).

27. If an evader is detected the undeclared tax is collected and a penalty rate ![eqn-27](https://latex.codecogs.com/svg.image?\pi) is applied over the undeclared tax.

28. In each period, employers have a probability of dying, following a Weibull quantile derivation function:

    ![eqn-28](https://latex.codecogs.com/svg.image?Q(p)=\lambda\left[\frac{1}{1-p}\right]^{\frac{1}{k}})

29. Where ![eqn-29](https://latex.codecogs.com/svg.image?\lambda=0.019) and ![eqn-29](https://latex.codecogs.com/svg.image?k=0.479) are the scale and shape parameter respectively.
30. It is assumed that when an employer dies, someone else takes their place with the same attributes, except for age, which is generated according to:

![eqn-30](https://latex.codecogs.com/svg.image?eda=\lfloor{X}\rfloor)

![eqn-30](https://latex.codecogs.com/svg.image?X\sim{N}(\mu,\sigma^{2})\sim{N}(37,6))

31. At each time ![eqn-31](https://latex.codecogs.com/svg.image?t), the observed output Extent of Tax Evasion is calculated as follows:

    ![eqn-31](https://latex.codecogs.com/svg.image?ETE_t=1-\frac{\sum_{i=1}^{N}W^{*}}{\sum_{i=1}^{N}W})

### References

-    J. Alm, (2011). «Measuring, explaining, and controlling tax evasion: lessons from theory, experiments, and field studies,» *International Tax and Public Finance*, pp. 54-77.
-    S. Hokamp, (2014). «Dynamics of tax evasion with back auditing, social norm updating, and public goods provision - An agent-based simulation,» *Journal of Economic Psychology,* pp. 187-199.
-    M. G. Allingham y A. Sandmo, (1972). «Income tax evasion: a theoretical analysis,» *Journal of Public Economics,* pp. 323-338.
-   V. Grimm, U. Berger, D. L. DeAngelis, J. G. Polhill, J. Giske y S. F. Railsback, (2010). «The ODD protocol: A review and first update,» *Ecological Modelling,* pp. 2760-2768.
-   A. Chakraborti & M. Patriarca, (2008). «Gamma-distribution and wealth inequality,» *Journal of physics,* pp. 233-243.
-   J. E. Pinder, J. G. Wiener y M. H. Smith, (1978). «The Weibull Distribution: A New Method of Summarizing Survivorship Data,» *Ecology,* pp. 175-179.
-   CONAPO, (2020). «Datos Abiertos. Indicadores demográficos 1950 - 2050.,» Consejo Nacional de Población, Ciudad de México.
