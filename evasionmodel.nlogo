; Model of Tax evasion

extensions [ gis csv R palette ]

breed[employers employer]     ; employers in the simulation
breed[auditors auditor]       ; auditors in the simulation

;-----------------------------------------------------------------------
; Variable definitions
globals [
  mx-states
]

employers-own [
  ; from ENOE
  t_loc	
  ent	
  sex	
  eda	
  n_hij	
  e_con	
  salario	
  c_ocu11c	
  ing7c	
  dur9c	
  ambito2	
  anios_esc	
  hrsocup	
  ingocup	
  tcco	
  scian	
  mh_col	
  year
  tax
  Corrupción
  Inseguridad

  ; simulation variables
  production            ; value produced in period
  payroll               ; payroll
  payroll*              ; declared payroll
  utility               ; utility due production
  utility-evasion       ; utility due evasion
  utility-total         ; utility due production + utility due evasion
  prob-formal           ; Probability of being formal employer
  risk-aversion-ρ       ; Risk aversion
  audited?              ; Employer was audited?
  s-α                   ; Subjective audit probability
  δ                     ; updating parameter for s-α
  ATPNI                 ; After Tax and Penalties Net Income
  utility-U             ; [0,1] optimized Utility
]

auditors-own [
  ent-auditor           ; Where do they audit?
  my-employers          ; Who do they audit?
  tax-collected         ; How much did they collect in taxes?
  penalty-collected     ; How much did they collect for penalties?
]

patches-own [
  ; GIS Layer variables
  centroid
  ID
  region

  tax-ent               ; Tax rate in each state
  Corrupción-ent        ; Perceived level of corruption (ENCIG)
  Inseguridad-ent       ; Perceived insecurity level (ENCIG)
]

; Some considerations:
; According to INEGI, in 2021, there are 2,591,777 employers
; 0.10% is 2,592 employers = 1: 1,000
; 0.05% is 1,296 employers = 1: 2,000
; 0.02%	is 518 employers   = 1: 5,000
; 0.01%	is 259 employers   = 1:10,000

;-----------------------------------------------------------------------
; setup procedures
to setup
  clear-all
  ;; clear the R workspace
  r:clear

  ; Load ML model
  setup-ML

  ; Set properties to the patches and agents
  setup-patches
  setup-map
  setup-employers
  start-auditors 32
  initialize-variables

  reset-ticks
end

to setup-ML
  ; Load packages
  r:eval "library(ranger)"
  r:eval "library(readr)"
  ;rfmodel2 - regression
  ;rfmodel1 - classification
  r:eval "rf <- readRDS('D:/Dropbox/Research/taxEvasion/evasion/rfmodel2.rds')"
end

to setup-patches
  ask patches [ set pcolor 87  ]
end

to setup-map
  ;; Load the dataset
  set mx-states gis:load-dataset "gis/mxhexbin.shp"
  ;; set the world envelope
  gis:set-world-envelope (gis:envelope-of mx-states)
  ;; Loop through the patches and find centroid and set ID


  let i 1
  foreach gis:feature-list-of mx-states [ feature ->
    ask patches gis:intersecting feature [
      set centroid gis:location-of gis:centroid-of feature
      ask patch item 0 centroid item 1 centroid [
        set ID i
      ]
    ]
    set i i + 1
  ]
  ;; Draw the outline of the counties in white
  gis:set-drawing-color white
  gis:draw mx-states 2

  gis:apply-coverage mx-states "ID" region
  gis:apply-coverage mx-states "TAX" tax-ent
  gis:apply-coverage mx-states "CORRUPCION" Corrupción-ent
  gis:apply-coverage mx-states "INSEGURIDA" Inseguridad-ent

  ask patches with [region > 0 or region < 0 or region = 0][
    set pcolor green
  ]

  ; legend colors
  ask patches with [pxcor > 40 and pxcor < 44 and pycor > 24 and pycor < 44][
    (ifelse
      color-palette = "viridis" [
        set pcolor palette:scale-gradient [[253 231 37] [33 145 140] [68 1 84] ] pycor 24 44
      ]
      color-palette = "inferno" [
        set pcolor palette:scale-gradient [[252 255 164] [188 55 84] [0 0 4]] pycor 24 44
      ]
      color-palette = "magma" [
        set pcolor palette:scale-gradient [[252 253 191] [183 55 121] [0 0 4]] pycor 24 44
      ]
      color-palette = "plasma" [
        set pcolor palette:scale-gradient [[240 249 33] [204 71 120] [13 8 135]] pycor 24 44
      ]
      color-palette = "cividis" [
        set pcolor palette:scale-gradient [[255 234 70] [124 123 120] [0 32 77]] pycor 24 44
      ]
      color-palette = "parula" [
        set pcolor palette:scale-gradient [[249 251 14] [51 183 160] [53 42 135]] pycor 24 44
      ]
    )
  ]


end

to setup-employers
  file-close-all
  (ifelse
    scale-for-number-of-employers = "1:2,000" [
      file-open "datos/ENOE_employers19_2k.csv"
    ]
    scale-for-number-of-employers = "1:3,000" [
      file-open "datos/ENOE_employers19_3k.csv"
    ]
    scale-for-number-of-employers = "1:4,000" [
      file-open "datos/ENOE_employers19_4k.csv"
    ]
    scale-for-number-of-employers = "1:5,000" [
      file-open "datos/ENOE_employers19_5k.csv"
    ]
    ; elsecommands
    [
      file-open "datos/ENOE_employers19_test.csv"
    ]
  )

  ;; To skip the header row in the while loop,
  ;  read the header row here to move the cursor
  ;  down to the next line.
  let headings csv:from-row file-read-line

  while [ not file-at-end? ] [
    let data csv:from-row file-read-line
    ;print data
    create-employers 1 [
      ; visual attributes
      set color blue
      set size 0.9
      set shape "factory"
			; ENOE attributes
      set t_loc	item 0 data
      set ent	item 1 data
      set sex	item 2 data
      set eda	item 3 data
      set n_hij	item 4 data
      set e_con	item 5 data
      set salario	item 6 data
      set c_ocu11c	item 7 data
      set ing7c	item 8 data
      set dur9c	item 9 data
      set ambito2	item 10 data
      set anios_esc	item 11 data
      set hrsocup	item 12 data
      set ingocup	item 13 data
      set tcco item 14 data
      set scian	item 15 data
      set mh_col item 16 data

      move-to one-of patches with [not any? employers-here and region = [ent] of myself]
    ]
  ]
  file-close-all

  ask employers with [mh_col = 0][set color red]
end

to start-auditors [#auditors]
  create-auditors #auditors[
    set color yellow
    set shape "person"
    set size 2
    set ent-auditor who - count employers + 1
  ]

  ask  auditors [
    move-to one-of patches with [not any? auditors-here and region = [ent-auditor] of myself]
  ]
end

to initialize-variables
  let avg 2
  let std-dev 0.1
  let alpha 3 / 2
  ask employers [
    ; Value of informal economy represents around 23% of total economy
    set production round ifelse-value (mh_col = 0)[
      23.00 * pareto avg (std-dev + 0.1) alpha
    ][
      50.00 * pareto avg (std-dev + 0.2) alpha
    ]
    ; Participacion of salaries in PIB are around %30 and %40
    set payroll floor production * 0.30
    set payroll* payroll ; At the beggining no employers evade
    set utility production - payroll
    set utility-evasion payroll - payroll*
    set utility-total utility + utility-evasion
    set prob-formal random-float 1    ; At the beggining is random
    set s-α α ; Typically we assume p = ps
    set δ -0.1
    set risk-aversion-ρ social-norm eda
    set audited? false

    ;Updated after tax-audit
    ;ATPNI
    ;utility-U

    ; Get propeeties from state (patch)
    set tax [tax-ent] of patch-here + Δθ
    set Corrupción [Corrupción-ent] of patch-here + ( ΔPC / 100 )
    set Inseguridad [Inseguridad-ent] of patch-here + ( ΔPI / 100 )

  ]

  ask auditors [
    set my-employers employers with [ent = [ent-auditor] of myself]
    set tax-collected 0
    set penalty-collected 0
  ]

end

;-----------------------------------------------------------------------
; Go procedure

to go
  ; A tick will represent a month
  if (ticks >= 120 ) [stop]
  ; Process overview and scheduling
  choose-market
  ;employers-produce
  calculate-utility
  tax-collection
  tax-audit
  age-increase
  adjust-subjetive
  paint-patches

  tick
end

to choose-market
  if (ticks > 0 and ticks mod 12 = 0)[
    ask employers [
      (r:putagentdf "newdata" self "mh_col" "ambito2" "anios_esc" "c_ocu11c" "ing7c" "t_loc" "eda" "ent" "tax" "Corrupción" "Inseguridad")
      r:eval "predict <- predict(rf, data = newdata)"
      let probability r:get "predict$predictions"
      set prob-formal probability
      set mh_col ifelse-value (probability > τ ) [1] [0]
      ;set mh_col r:get "predict$predictions"
    ]
  ]
end

to tax-collection
  ask auditors [
    set tax-collected sum [payroll*] of my-employers
  ]
end

to tax-audit
  ask auditors [
    ;move-to one-of neighbors with [region = [ent-auditor] of myself]
    let my-audited-employer one-of my-employers
    ; IF:
    ;    any employer found
    ;    AND employer evaded an amount
    ;    AND audit process is succesfull
    if (;any? my-audited-employer and item 0
      ([utility-evasion] of my-audited-employer) > 0 and ε-ap > random-float 1)[
      ; Just one period and one employer collected
      set penalty-collected (1 + π) * [utility-evasion] of my-audited-employer
    ]

    ask my-audited-employer [
      set audited? true
      set s-α 1
      set utility-evasion 0
      set utility utility - ( π * payroll* )
    ]

  ]
end

to calculate-utility

  ask employers with [audited?][
    let T sum [tax-collected] of auditors with [ent-auditor = [ent] of myself]
    let P sum [penalty-collected] of auditors with [ent-auditor = [ent] of myself]
    let PG T + P
    let I payroll
    let θ tax
    let X prob-formal * I
    let β 1 - Inseguridad
    let PG-i PG - (θ * X) - π * (I - X)
    let net-income I - (θ * X) + β * ((θ * X ) * (1 - ε-tc) + PG-i)

    set ATPNI ATPNI - (1 - β * (1 - ε-ap)) * ( π * (I - X))
    set payroll* X
    set utility production - payroll
    set utility-evasion payroll - payroll*
    set utility-total utility + utility-evasion
    set utility-U 1 - exp (- risk-aversion-ρ * ATPNI)
  ]

  ask employers with [not audited?][
    let T sum [tax-collected] of auditors with [ent-auditor = [ent] of myself]
    let P sum [penalty-collected] of auditors with [ent-auditor = [ent] of myself]
    let PG T + P
    let I payroll
    let θ tax
    let X prob-formal * I
    let β 1 - Inseguridad
    let PG-i PG - (θ * X) - π * (I - X)

    set ATPNI I - (θ * X) + β * ((θ * X ) * (1 - ε-tc) + PG-i)
    set payroll* X
    set utility production - payroll
    set utility-evasion payroll - payroll*
    set utility-total utility + utility-evasion
    set utility-U 1 - exp (- risk-aversion-ρ * ATPNI)
  ]

end

to adjust-subjetive
  ask employers with [s-α > α][
    set s-α s-α + δ
  ]

  ask employers with [s-α < α][
    set s-α α
    set audited? false
  ]
end

to age-increase
  ; Increase age of employers each 12 months
  if (ticks > 0 and ticks mod 12 = 0)[
    ask employers [
      set eda eda + 1
      if (eda > 100)[
        set eda random-normal 37 6
      ]
    ]
  ]
  ; In Mexico, lifetime expentancy at birth is 75 years
  ; https://www.ssa.gov/oact/STATS/table4c6.html#fn1
  ; https://math.stackexchange.com/questions/51230/quantile-function-with-normal-distribution-and-weibull-distribution
  ; Weibull quantile derivation:
  ; Q(p) = λ * (log(1 / 1 - (1 - p)))^(1/k) where λ scale parameter, and k is shape parameter
  let λ 0.01973383
  let k 0.4792089
  ask employers [
    let p eda / 110
    let Qp λ * (ln((1 / p)))^(1 / k)
    if (random-float 1 < Qp )[
      set eda random-normal 37 6
    ]
  ]
end

to paint-patches
  let max-collection max [tax-collected + penalty-collected] of auditors
  let min-collection min [tax-collected + penalty-collected] of auditors
  ask patches with [region > 0 or region < 0 or region = 0][
    let taxes sum [tax-collected] of auditors with [ent-auditor = [region] of myself]
    let penalties sum [penalty-collected] of auditors with [ent-auditor = [region] of myself]
    let taxes+penalties taxes + penalties

    (ifelse
      color-palette = "viridis" [
        set pcolor palette:scale-gradient [[253 231 37] [33 145 140] [68 1 84] ] taxes+penalties min-collection max-collection
      ]
      color-palette = "inferno" [
        set pcolor palette:scale-gradient [[252 255 164] [188 55 84] [0 0 4]] taxes+penalties min-collection max-collection
      ]
      color-palette = "magma" [
        set pcolor palette:scale-gradient [[252 253 191] [183 55 121] [0 0 4]] taxes+penalties min-collection max-collection
      ]
      color-palette = "plasma" [
        set pcolor palette:scale-gradient [[240 249 33] [204 71 120] [13 8 135]] taxes+penalties min-collection max-collection
      ]
      color-palette = "cividis" [
        set pcolor palette:scale-gradient [[255 234 70] [124 123 120] [0 32 77]] taxes+penalties min-collection max-collection
      ]
      color-palette = "parula" [
        set pcolor palette:scale-gradient [[249 251 14] [51 183 160] [53 42 135]] taxes+penalties min-collection max-collection
      ]
    )

  ]

end


;-----------------------------------------------------------------------
; reporters

to-report gibrat [ mn std ]
  let s2 std ^ 2
  let x random-normal mn std
  let first-term 1 / (x * sqrt (2 * pi * s2))
  let second-term exp (- ((log (x / mn ) 2 ) / (2 * s2 )) )
  report first-term * second-term
end

to-report pareto [ mn std alp ]
  let x random-normal mn std
  report ( 1 / (x ^ (1 + alp)))
end

to-report social-norm [age]
  (ifelse
    age <= 34 [
      report random-float 0.25
    ]
    age <= 51 [
      report 0.25 + random-float 0.25
    ]
    age <= 67 [
      report 0.50 + random-float 0.25
    ]
    ; elsecommands
    [
      report 0.75 + random-float 0.25
  ])
end
@#$#@#$#@
GRAPHICS-WINDOW
258
10
750
423
-1
-1
4.0
1
10
1
1
1
0
1
1
1
-60
60
-50
50
0
0
1
ticks
30.0

BUTTON
9
10
72
43
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
114
11
177
44
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
918
311
997
356
No. auditors
count auditors
0
1
11

MONITOR
763
261
849
306
No. employers
count employers
0
1
11

MONITOR
763
311
917
356
GDP of informal economy (%)
100 * ( sum [payroll] of employers with [mh_col = 0] / sum [payroll] of employers)
2
1
11

CHOOSER
8
49
211
94
scale-for-number-of-employers
scale-for-number-of-employers
"1:2,000" "1:3,000" "1:4,000" "1:5,000" "test"
0

PLOT
763
13
998
133
Distribution of payroll
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"set-plot-x-range 0 round max [payroll] of employers\nset-plot-y-range 0 sqrt count employers\nset-histogram-num-bars sqrt count employers" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [payroll] of employers"

PLOT
763
135
998
255
Age distribution
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"set-plot-x-range 18 101\nset-plot-y-range 0 sqrt count employers\nset-histogram-num-bars sqrt count employers" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [eda] of employers"

SLIDER
14
420
127
453
τ
τ
0
1
0.5
0.01
1
NIL
HORIZONTAL

MONITOR
850
261
997
306
% of informal employers
100 * ( count employers with [mh_col = 0] / count employers)
2
1
11

SLIDER
8
120
128
153
π
π
0.1
1
0.5
0.01
1
NIL
HORIZONTAL

SLIDER
8
157
128
190
α
α
0
1
0.1
0.01
1
NIL
HORIZONTAL

PLOT
1000
13
1234
133
Probability X
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"set-plot-x-range 0 1\nset-plot-y-range 0 1\nset-histogram-num-bars sqrt count employers" "set-plot-y-range 0 1"
PENS
"default" 1.0 1 -16777216 true "" "histogram [prob-formal] of employers"

SLIDER
11
215
126
248
ε-ap
ε-ap
0
1
0.75
0.01
1
NIL
HORIZONTAL

TEXTBOX
11
198
161
216
Effectiveness of
11
0.0
1

TEXTBOX
136
225
249
243
Audit process
11
0.0
1

SLIDER
11
251
126
284
ε-tc
ε-tc
0
1
0.7
0.01
1
NIL
HORIZONTAL

TEXTBOX
135
261
250
279
Tax collection
11
0.0
1

PLOT
1000
135
1234
255
utility-U
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"set-plot-x-range 0 1.1\nset-plot-y-range 0 1\nset-histogram-num-bars sqrt count employers" "set-plot-y-range 0 1"
PENS
"default" 1.0 1 -16777216 true "" "histogram [utility-U] of employers"

PLOT
1235
13
1469
133
The Extent of Tax Evasion
month
NIL
0.0
10.0
0.0
10.0
true
false
"set-plot-x-range 0 120\nset-plot-y-range 0 1" ""
PENS
"default" 1.0 0 -16777216 true "" "plot 1 - (sum [payroll*] of employers / sum [payroll] of employers)"

PLOT
1235
135
1469
255
Collected penalties
month
NIL
0.0
10.0
0.0
10.0
true
false
"set-plot-x-range 0 120" ""
PENS
"Penalties" 1.0 0 -955883 true "" "plot sum [penalty-collected] of auditors"

PLOT
1000
257
1234
377
Collected tax
month
NIL
0.0
10.0
0.0
10.0
true
false
"set-plot-x-range 0 120" ""
PENS
"default" 1.0 0 -14835848 true "" "plot sum [tax-collected] of auditors"

TEXTBOX
11
293
161
311
decrease / increase 
11
0.0
1

SLIDER
14
312
127
345
Δθ
Δθ
-1
3
0.0
0.5
1
%
HORIZONTAL

SLIDER
14
348
127
381
ΔPI
ΔPI
-15
15
0.0
1
1
%
HORIZONTAL

TEXTBOX
136
322
249
340
Tax rate
11
0.0
1

TEXTBOX
136
358
248
380
Perceived insecurity\n
11
0.0
1

TEXTBOX
10
103
160
121
Fiscal environment
11
0.0
1

TEXTBOX
137
130
249
148
Penalty rate
11
0.0
1

TEXTBOX
137
167
249
185
Audit probability
11
0.0
1

SLIDER
14
384
127
417
ΔPC
ΔPC
-15
15
-15.0
1
1
%
HORIZONTAL

TEXTBOX
136
394
250
412
Perceived corruption
11
0.0
1

TEXTBOX
136
425
250
453
Decision threshold\nto be in formal sector
11
0.0
1

TEXTBOX
272
432
399
460
Visualization of tax collected
11
0.0
1

CHOOSER
368
427
506
472
color-palette
color-palette
"viridis" "inferno" "magma" "plasma" "cividis" "parula"
5

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

factory
false
0
Rectangle -7500403 true true 76 194 285 270
Rectangle -7500403 true true 36 95 59 231
Rectangle -16777216 true false 90 210 270 240
Line -7500403 true 90 195 90 255
Line -7500403 true 120 195 120 255
Line -7500403 true 150 195 150 240
Line -7500403 true 180 195 180 255
Line -7500403 true 210 210 210 240
Line -7500403 true 240 210 240 240
Line -7500403 true 90 225 270 225
Circle -1 true false 37 73 32
Circle -1 true false 55 38 54
Circle -1 true false 96 21 42
Circle -1 true false 105 40 32
Circle -1 true false 129 19 42
Rectangle -7500403 true true 14 228 78 270

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
