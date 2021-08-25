## An agent-based simulation assisted by machine learning for the analysis of payroll tax evasion
Alejandro Platas-López & Alejandro Guerra-Hernández

### Introduction
Tax evasion is an illegal and intentional activity taken by individuals to reduce their legally due tax obligations. With the large amount of data available in the National Institute of Statistics and Geography, this model introduces an agent-based model and simulation linked to a machine-learning model for the analysis of payroll tax evasion, a kind of tax that employers must paid on the wages and salaries of employees. 

Each state has autonomy over the way in which the payroll tax is collected. Therefore, to model these different fiscal scenarios and their effects, an explicit representation of the space is made through a Geographic Information System with hexagonal tessellation. The effects of quality in the provision of public goods, on tax compliance are also explored. 

A priori, a random forest model is obtained from the National Survey of Occupation and Employment and the National Survey of Quality and Government Impact. At the beginning of simulation employer agents in the model get some properties directly from the data set and use the learned model to derive some others during the simulation. Within the framework presented by Hokamp (2014), novel insights into payroll tax compliance driven by the quality of public goods provision, and social norms are presented. 

Taxpayers rely on Allingham and Sandmo's expected utility maximization. So, in each period, the decision on the amount to be declared made by the employers, is the one that maximizes their utility. The model is defined following the ODD (Overview, Design concepts, and Details) Protocol and implemented in NetLogo. Since this approach capture complex real-world phenomena more realistically, the model is promoted as a toolbox for studying fiscal and public policy implications in tax collection. It was found that the perception of the quality of the goods provided by the state has a significant effect on the collection of taxes. Finally, our sensitivity analysis provides numerical estimates that reveal the strong impact of the penalty and tax rate on tax evasion.

### Configuration
#### R
Install the following R packages from CRAN, just run

```R
install.packages("rJava")
install.packages("ranger")
install.packages("readr")
```

#### Netlogo
Configure the R extention appropriately. 

### ODD protocol

#### Overview
##### Purpose


##### Entities, state variables, and scales
-   Agents: 
-   Environment: 
-   State variables: 
-   Scales:

##### Process overview and scheduling

1.
2.
3.
4.
5.

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