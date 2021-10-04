; Model of Tax evasion

extensions [ gis csv R palette pathdir]

breed[employers employer]     ; employers in the simulation
breed[auditors auditor]       ; auditors in the simulation

;-----------------------------------------------------------------------
; Variable definitions
globals [
  mx-states
  ; to test wich equation is used
  audits
]

employers-own [
  ; from ENOE
  t_loc
  ent
  eda
  c_ocu11c
  ing7c
  ambito2
  anios_esc
  ingocup
  mh_col
  year
  ; from the tax legislations
  tax
  ; from ENCIG
  corruption
  insecurity

  ; simulation variables
  production            ; value produced in period
  payroll               ; payroll
  payroll*              ; declared payroll
  undeclared-payroll    ; Unreported payroll
  declared-tax          ; tax * declared payroll
  undeclared-tax        ; tax * undeclared-payroll
  type-of-taxpayer      ; 0 = fully evades; 1 = partial tax compliant; 2 = fully tax compliant

  prob-formal           ; Probability of being formal employer
  risk-aversion-ρ       ; Risk aversion
  audit?                ; Employer elegible to audit
  audited?              ; Employer was audited?
  α-s                   ; Subjective audit probability
  δ                     ; updating parameter for α-s
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

  tax-ent               ; Tax rate in each state (tax legislation)
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
  if (machine-learning?)[
    ; Load packages
    r:eval "library(ranger)"
    r:eval "library(readr)"
    r:eval str-replace replace-item 15 "rf <- readRDS('P\\rfmodel2.rds')" pathdir:get-model-path
  ]
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
  gis:apply-coverage mx-states "CORRUPTION" Corrupción-ent
  gis:apply-coverage mx-states "INSECURITY" Inseguridad-ent

  ask patches with [region > 0 or region < 0 or region = 0][
    set pcolor green
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
      set eda	item 2 data
      set c_ocu11c	item 3 data
      set ing7c	item 4 data
      set ambito2	item 5 data
      set anios_esc	item 6 data
      set ingocup	item 7 data
      set mh_col item 8 data

      move-to one-of patches with [not any? employers-here and region = [ent] of myself]
    ]
  ]
  file-close-all

  ask employers with [mh_col = 0][set color red]
end

to start-auditors [#auditors]
  create-auditors #auditors[
    set color white
    set shape "person"
    set size 0.1
    set ent-auditor who - count employers + 1   ; Assign one auditor per state
  ]

  if ( Abbrev-states )[
    ask  auditors [
      ; Auditors move to their assigned state
      let my-state  patches with [region = [ent-auditor] of myself]
      let x-position 11 + min [pxcor] of my-state
      let y-position -2 + max [pycor] of my-state
      setxy x-position y-position
      set label entidad ent-auditor
      set label-color black
    ]
  ]
end

to initialize-variables
  let avg 2
  let std-dev 0.1
  let alpha 3 / 2
  ask employers [
    ; Value of informal economy represents around 23% of total economy
    let avg-income mean [ingocup] of employers with [ent = [ent] of myself]
    set production round ifelse-value (mh_col = 0)[
      (23.00 + ln (avg-income) ) * pareto (avg + (log (ambito2 + 1) 10)) (std-dev + 0.1) alpha
    ][
      (50.00 + ln (avg-income) ) * pareto (avg + (log (ambito2 + 1) 10)) (std-dev + 0.2) alpha
    ]
    ; Participacion of salaries in PIB are around %30 and %40
    set payroll floor production * 0.30
    set payroll* payroll ; At the beggining no employers evade
    set declared-tax (tax / 100) * payroll*
    set undeclared-payroll 0
    set undeclared-tax 0
    set type-of-taxpayer 2
    set prob-formal random-float 1    ; At the beggining is random
    set α-s α ; Typically we assume p = ps
    set δ -0.1
    set risk-aversion-ρ social-norm eda
    set audit? false
    set audited? false

    ; Get properties from state (patch)
    set tax max (list 0 ( [tax-ent] of patch-here + Δθ))
    set corruption [Corrupción-ent] of patch-here + ( ΔPC / 100 )
    set insecurity [Inseguridad-ent] of patch-here + ( ΔPI / 100 )

  ]

  ask auditors [
    set my-employers employers with [ent = [ent-auditor] of myself]
    set tax-collected 0
    set penalty-collected 0
  ]

end

;-----------------------------------------------------------------------
; GO

to go
  ; A tick will represent a month
  if (ticks >= 120 ) [stop]
  ; Process overview and scheduling
  choose-market
  declaration
  tax-collection
  tax-audit
  age-increase
  adjust-subjetive
  visualization

  tick
end

;;;; CHOOSE-MARKET
; In this process employers, based on their attributes and sensed environment, decide to be in formal or informal sector
; The global variable τ (tau) will be changed in order to change de decisión threshold of employer

to choose-market
  set audits 0
  if (machine-learning?)[
    if (ticks > 0 and ticks mod 12 = 0)[
      ;(r:putagentdf "newdata" employers "mh_col" "ambito2" "anios_esc" "c_ocu11c" "ing7c" "t_loc" "eda" "ent" "tax" "Corrupción" "Inseguridad")
      (r:putagentdf "newdata" employers "mh_col" "ambito2" "anios_esc" "c_ocu11c" "ing7c" "t_loc" "eda" "ent" "tax" "corruption" "insecurity")
      ;r:eval "write.csv(newdata, 'D:/Dropbox/Research/taxEvasion/evasion/newdata.csv')"
      r:eval "predict <- predict(rf, data = newdata)"
      let probability r:get "round(predict$predictions, 3)"

      let n 0
      foreach sort employers [ the-employer ->
        ask the-employer [
          set prob-formal item n probability
          set mh_col ifelse-value (item n probability > τ ) [1] [0]
          set n n + 1
        ]
      ]
    ]
  ]
end


;;;; DECLARATION
; In this process, employers decide the amount of wages to declare to the tax authority.
; For details about equations see Hokamp and Cuervo Díaz, 2018.
; DOI: https://doi.org/10.1002/9781119155713.ch9
to declaration
  ; Informal employers do not declare taxes, i.e. payroll* = 0
  ask employers with [mh_col = 0][
    set payroll* 0                                    ; declared payroll
    set undeclared-payroll payroll - payroll*
    set undeclared-tax (tax / 100) * undeclared-payroll
    set type-of-taxpayer 0
  ]

  ; Formal employers declares payroll*, where 0 < payroll* <= 1
  ask employers with [mh_col = 1][
    let β 1 - insecurity                             ; Public goods efficiency
    let θ tax / 100
    let ρ risk-aversion-ρ
    let I payroll
    let BA 0

    let aux.eqn1 (1 - β * (1 - ε-ap))
    let aux.eqn2 (1 - β * (1 - ε-tc))

    let eqn9.4 1 / ((1 + (((aux.eqn1 * π )  / ( aux.eqn2 * θ ) ) - 1 )) * (exp (ρ * aux.eqn1 * (π * I +  BA))))
    let eqn9.5 1 / ((1 + (((aux.eqn1 * π )  / ( aux.eqn2 * θ ) ) - 1 )) * (exp (ρ * aux.eqn1 * (BA))))

    (ifelse
      α-s < eqn9.4 [
        set payroll* 0 ; employer fully evades
        set declared-tax 0
        set undeclared-payroll payroll
        set undeclared-tax θ * undeclared-payroll
        set type-of-taxpayer 0
      ]
      α-s > eqn9.5 [
        set payroll* payroll ; employer becomes fully tax compliant
        set declared-tax θ * payroll*
        set undeclared-payroll 0
        set undeclared-tax 0
        set type-of-taxpayer 2
      ]
      ; employer voluntarily declares:
      [
        let eqn9.6 I + (BA / π) - ((ln ( ((1 - α-s) * aux.eqn2 * θ) / (α-s * ((aux.eqn1) * π - (aux.eqn2) * θ)))) / (ρ * π * aux.eqn1))
        if (eqn9.6 < 0)[
          set payroll* max (list 0 eqn9.6)
          set type-of-taxpayer 0
        ]
        set payroll* eqn9.6
        set declared-tax θ * payroll*
        set undeclared-payroll payroll - payroll*
        set undeclared-tax θ * undeclared-payroll
        set type-of-taxpayer 1
      ]
    )
  ]
end


;;;; TAX-COLLECTION
; The tax authority collects payroll taxes that employers voluntarily declared
to tax-collection
  ask auditors [
    set tax-collected sum [declared-tax] of my-employers
  ]
end


;;;; TAX-AUDIT
; The tax authority carries out a series of random audits with a certain level of effectiveness.
; Detected evaders must pay a penalty rate (which must be higher than the tax) on undeclared wages.
to tax-audit
  ; Randomly choose employers to audit
  ask auditors [
    ask my-employers with [mh_col = 1][
      if (random-float 1 < α)[
        set audit? true
        set α-s 1 +  abs δ          ; Change subjective audit probability
        set audits audits + 1
      ]
    ]
  ]

  ask auditors [
    let employers-to-audit my-employers with [audit? and undeclared-payroll > 0]
    if (any? employers-to-audit)[
      ; Finalize audit for fully tax compliant employers
      ask employers-to-audit with [undeclared-payroll <= 0][
        set audit? false
        set audited? true
        set α-s 1 +  abs δ          ; Change subjective audit probability
      ]
    ]

    set employers-to-audit my-employers with [audit?]
    if (any? employers-to-audit)[
      ; If the audit is unsuccessful with probability ε-ap,
      ; the audit ends for the employer, even if it is evader
      ask employers-to-audit with [audit?][
        if (random-float 1 > ε-ap)[
          set audit? false
          set audited? true
          set α-s 1 +  abs δ          ; Change subjective audit probability
        ]
      ]
    ]

    set employers-to-audit my-employers with [audit?]
    if (any? employers-to-audit)[
      ; The remaining audits are successful
      ; And penalties are applied
      set penalty-collected (1 + π) * sum [undeclared-tax] of employers-to-audit
      ; the audit ends for the employer
      ask employers-to-audit [
        set payroll* payroll
        set declared-tax (tax / 100) * payroll*
        set undeclared-payroll 0                  ; The undeclared amount becomes zero
        set undeclared-tax 0
        set audit? false
        set audited? true
      ]
    ]
  ]
end

;;;; ADJUST-SUBJECIVE
; Update subjective audit probability
; each period decrease in δ amount
to adjust-subjetive
  ask employers with [α-s > α][
    set α-s α-s + δ
  ]

  ask employers with [α-s < α][
    set α-s α
    set audited? false
  ]
end

;;;; AGE-INCREASE
; Every 12 months employers increase their age by 1 year.
; In each period, employers have a probability of dying,
; which follows a Weibull distribution function adjusted for the case of Mexico,
; where life expectancy at birth is 75 years.
; It is assumed that when an employer dies, someone else takes their place with
; the same characteristics, except for age, which is generated randomly.
to age-increase
  ; Increase age of employers each 12 months
  if (ticks > 0 and ticks mod 12 = 0)[
    ask employers [
      set eda eda + 1
      if (eda > 100)[
        set eda ceiling random-normal 37 6
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

;;;; VISUALIZATION
; For visualization purposes, this procedure colors the polygons according to the tax collection and colors the employers according their type of taxpayer.
to visualization
  let max-collection max [tax-collected + penalty-collected] of auditors
  let min-collection min [tax-collected + penalty-collected] of auditors

  ; legend colors
  if (ticks = 1)[
    ask patches with [pxcor > 40 and pxcor < 44 and pycor > 24 and pycor < 44][
      (ifelse
        color-palette = "viridis" [
          set pcolor palette:scale-gradient [[ 68 1 84 ][ 68 58 131 ][ 49 104 142 ][ 33 144 140 ][ 53 183 121 ][ 143 215 68 ][ 253 231 37 ]] pycor 24 44
        ]
        color-palette = "inferno" [
          set pcolor palette:scale-gradient [[ 0 0 4 ][ 51 10 95 ][ 120 28 109 ][ 187 55 84 ][ 237 105 37 ][ 252 181 25 ][ 252 255 164 ]] pycor 24 44
        ]
        color-palette = "magma" [
          set pcolor palette:scale-gradient [[ 0 0 4 ][ 45 17 96 ][ 114 31 129 ][ 182 54 121 ][ 241 96 93 ][ 254 175 119 ][ 252 253 191 ]] pycor 24 44
        ]
        color-palette = "plasma" [
          set pcolor palette:scale-gradient [[ 240 249 33 ][ 253 179 47 ][ 237 121 83 ][ 204 70 120 ][ 156 23 158 ][ 93 1 166 ][ 13 8 135 ]] pycor 24 44
        ]
        color-palette = "cividis" [
          set pcolor palette:scale-gradient [[ 0 32 77 ][ 35 62 108 ][ 87 92 109 ][ 124 123 120 ][ 166 157 117 ][ 211 193 100 ][ 255 234 70 ]] pycor 24 44
        ]
        color-palette = "parula" [
          set pcolor palette:scale-gradient [[249 251 14] [51 183 160] [53 42 135]] pycor 24 44
        ]
      color-palette = "turbo" [
          set pcolor palette:scale-gradient [[ 48 18 59 ][ 70 134 251 ][ 26 228 182 ][ 162 252 60 ][ 250 186 57 ][ 228 70 10 ][ 122 4 3 ]] pycor 24 44
      ]
      )
    ]
  ]

  ; paint polygons
  ask patches with [region > 0 or region < 0 or region = 0][
    let taxes sum [tax-collected] of auditors with [ent-auditor = [region] of myself]
    let penalties sum [penalty-collected] of auditors with [ent-auditor = [region] of myself]
    let t+p taxes + penalties

    (ifelse
      color-palette = "viridis" [
        set pcolor palette:scale-gradient [[ 68 1 84 ][ 68 58 131 ][ 49 104 142 ][ 33 144 140 ][ 53 183 121 ][ 143 215 68 ][ 253 231 37 ]] t+p min-collection max-collection
      ]
      color-palette = "inferno" [
        set pcolor palette:scale-gradient [[ 0 0 4 ][ 51 10 95 ][ 120 28 109 ][ 187 55 84 ][ 237 105 37 ][ 252 181 25 ][ 252 255 164 ]] t+p min-collection max-collection
      ]
      color-palette = "magma" [
        set pcolor palette:scale-gradient [[ 0 0 4 ][ 45 17 96 ][ 114 31 129 ][ 182 54 121 ][ 241 96 93 ][ 254 175 119 ][ 252 253 191 ]] t+p min-collection max-collection
      ]
      color-palette = "plasma" [
        set pcolor palette:scale-gradient [[ 240 249 33 ][ 253 179 47 ][ 237 121 83 ][ 204 70 120 ][ 156 23 158 ][ 93 1 166 ][ 13 8 135 ]] t+p min-collection max-collection
      ]
      color-palette = "cividis" [
        set pcolor palette:scale-gradient [[ 0 32 77 ][ 35 62 108 ][ 87 92 109 ][ 124 123 120 ][ 166 157 117 ][ 211 193 100 ][ 255 234 70 ]] t+p min-collection max-collection
      ]
      color-palette = "parula" [
        set pcolor palette:scale-gradient [[249 251 14] [51 183 160] [53 42 135]] t+p min-collection max-collection
      ]
      color-palette = "turbo" [
        set pcolor palette:scale-gradient [[ 48 18 59 ][ 70 134 251 ][ 26 228 182 ][ 162 252 60 ][ 250 186 57 ][ 228 70 10 ][ 122 4 3 ]] t+p min-collection max-collection
      ]
    )

  ]

  ; legend text
  ask patches with [pxcor = 49 and pycor = 43][
    set plabel precision max-collection 2
    set plabel-color 1
  ]

  ask patches with [pxcor = 49 and pycor = 25][
    set plabel precision min-collection 2
    set plabel-color 1
  ]

  ; name of legend
  ask patches with [pxcor = 51 and pycor = 46][
    set plabel "Tax collection ($)"
    set plabel-color 1
  ]

  ; Update color of agents
  ask employers with [type-of-taxpayer = 0][set color red]
  ask employers with [type-of-taxpayer = 1][set color cyan]
  ask employers with [type-of-taxpayer = 2][set color blue]


  ; export world and interface
  ;if (ticks > 0 and ticks mod 3 = 0)[
  ;  export-view (word "export/view/view-"  ticks ".png")
  ;  export-interface (word "export/inte/inte-"  ticks ".png")
  ;]

end


;-----------------------------------------------------------------------
; REPORTERS
; TODO: Add reporters for plots and outputs

to-report str-replace [ str ]
  let where position "\\" str
  ifelse is-number? where
  [
    report str-replace replace-item ( position "\\" str) str "/"
  ][
    report str
  ]
end

to-report gibrat [ mn std ]
  let s2 std ^ 2
  let x random-normal mn std
  let first-term 1 / (x * sqrt (2 * pi * s2))
  let second-term exp (- ((log (x / mn ) 2 ) / (2 * s2 )) )
  report first-term * second-term
end

; Reporter to produce Pareto distribution
to-report pareto [ mn std alp ]
  let x random-normal mn std
  report ( 1 / (x ^ (1 + alp)))
end

; Reporter to adapt risk aversion ρ
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

; Reporter for Extent of Tax Evasion
to-report ETE  report 1 - ( sum [payroll*] of employers / sum [payroll] of employers ) end

; Reporter for Extent of Tax Evasion of formal sector
to-report ETE-formal
  report 1 - ( sum [payroll*] of employers with [mh_col = 1] / sum [payroll] of employers with [mh_col = 1])
end

; ETE by state
to-report ETE01 report 1 - ( sum [payroll*] of employers with [region = 1] / sum [payroll] of employers with [region = 1]) end
to-report ETE02 report 1 - ( sum [payroll*] of employers with [region = 2] / sum [payroll] of employers with [region = 2]) end
to-report ETE03 report 1 - ( sum [payroll*] of employers with [region = 3] / sum [payroll] of employers with [region = 3]) end
to-report ETE04 report 1 - ( sum [payroll*] of employers with [region = 4] / sum [payroll] of employers with [region = 4]) end
to-report ETE05 report 1 - ( sum [payroll*] of employers with [region = 5] / sum [payroll] of employers with [region = 5]) end
to-report ETE06 report 1 - ( sum [payroll*] of employers with [region = 6] / sum [payroll] of employers with [region = 6]) end
to-report ETE07 report 1 - ( sum [payroll*] of employers with [region = 7] / sum [payroll] of employers with [region = 7]) end
to-report ETE08 report 1 - ( sum [payroll*] of employers with [region = 8] / sum [payroll] of employers with [region = 8]) end
to-report ETE09 report 1 - ( sum [payroll*] of employers with [region = 9] / sum [payroll] of employers with [region = 9]) end
to-report ETE10 report 1 - ( sum [payroll*] of employers with [region = 10] / sum [payroll] of employers with [region = 10]) end
to-report ETE11 report 1 - ( sum [payroll*] of employers with [region = 11] / sum [payroll] of employers with [region = 11]) end
to-report ETE12 report 1 - ( sum [payroll*] of employers with [region = 12] / sum [payroll] of employers with [region = 12]) end
to-report ETE13 report 1 - ( sum [payroll*] of employers with [region = 13] / sum [payroll] of employers with [region = 13]) end
to-report ETE14 report 1 - ( sum [payroll*] of employers with [region = 14] / sum [payroll] of employers with [region = 14]) end
to-report ETE15 report 1 - ( sum [payroll*] of employers with [region = 15] / sum [payroll] of employers with [region = 15]) end
to-report ETE16 report 1 - ( sum [payroll*] of employers with [region = 16] / sum [payroll] of employers with [region = 16]) end
to-report ETE17 report 1 - ( sum [payroll*] of employers with [region = 17] / sum [payroll] of employers with [region = 17]) end
to-report ETE18 report 1 - ( sum [payroll*] of employers with [region = 18] / sum [payroll] of employers with [region = 18]) end
to-report ETE19 report 1 - ( sum [payroll*] of employers with [region = 19] / sum [payroll] of employers with [region = 19]) end
to-report ETE20 report 1 - ( sum [payroll*] of employers with [region = 20] / sum [payroll] of employers with [region = 20]) end
to-report ETE21 report 1 - ( sum [payroll*] of employers with [region = 21] / sum [payroll] of employers with [region = 21]) end
to-report ETE22 report 1 - ( sum [payroll*] of employers with [region = 22] / sum [payroll] of employers with [region = 22]) end
to-report ETE23 report 1 - ( sum [payroll*] of employers with [region = 23] / sum [payroll] of employers with [region = 23]) end
to-report ETE24 report 1 - ( sum [payroll*] of employers with [region = 24] / sum [payroll] of employers with [region = 24]) end
to-report ETE25 report 1 - ( sum [payroll*] of employers with [region = 25] / sum [payroll] of employers with [region = 25]) end
to-report ETE26 report 1 - ( sum [payroll*] of employers with [region = 26] / sum [payroll] of employers with [region = 26]) end
to-report ETE27 report 1 - ( sum [payroll*] of employers with [region = 27] / sum [payroll] of employers with [region = 27]) end
to-report ETE28 report 1 - ( sum [payroll*] of employers with [region = 28] / sum [payroll] of employers with [region = 28]) end
to-report ETE29 report 1 - ( sum [payroll*] of employers with [region = 29] / sum [payroll] of employers with [region = 29]) end
to-report ETE30 report 1 - ( sum [payroll*] of employers with [region = 30] / sum [payroll] of employers with [region = 30]) end
to-report ETE31 report 1 - ( sum [payroll*] of employers with [region = 31] / sum [payroll] of employers with [region = 31]) end
to-report ETE32 report 1 - ( sum [payroll*] of employers with [region = 32] / sum [payroll] of employers with [region = 32]) end


;
to-report evasion
  report sum [undeclared-tax] of employers
end

; report evasion by state
to-report  undeclared01 report sum [undeclared-tax] of employers with [region =  1] end
to-report  undeclared02 report sum [undeclared-tax] of employers with [region =  2] end
to-report  undeclared03 report sum [undeclared-tax] of employers with [region =  3] end
to-report  undeclared04 report sum [undeclared-tax] of employers with [region =  4] end
to-report  undeclared05 report sum [undeclared-tax] of employers with [region =  5] end
to-report  undeclared06 report sum [undeclared-tax] of employers with [region =  6] end
to-report  undeclared07 report sum [undeclared-tax] of employers with [region =  7] end
to-report  undeclared08 report sum [undeclared-tax] of employers with [region =  8] end
to-report  undeclared09 report sum [undeclared-tax] of employers with [region =  9] end
to-report  undeclared10 report sum [undeclared-tax] of employers with [region =  10] end
to-report  undeclared11 report sum [undeclared-tax] of employers with [region =  11] end
to-report  undeclared12 report sum [undeclared-tax] of employers with [region =  12] end
to-report  undeclared13 report sum [undeclared-tax] of employers with [region =  13] end
to-report  undeclared14 report sum [undeclared-tax] of employers with [region =  14] end
to-report  undeclared15 report sum [undeclared-tax] of employers with [region =  15] end
to-report  undeclared16 report sum [undeclared-tax] of employers with [region =  16] end
to-report  undeclared17 report sum [undeclared-tax] of employers with [region =  17] end
to-report  undeclared18 report sum [undeclared-tax] of employers with [region =  18] end
to-report  undeclared19 report sum [undeclared-tax] of employers with [region =  19] end
to-report  undeclared20 report sum [undeclared-tax] of employers with [region =  20] end
to-report  undeclared21 report sum [undeclared-tax] of employers with [region =  21] end
to-report  undeclared22 report sum [undeclared-tax] of employers with [region =  22] end
to-report  undeclared23 report sum [undeclared-tax] of employers with [region =  23] end
to-report  undeclared24 report sum [undeclared-tax] of employers with [region =  24] end
to-report  undeclared25 report sum [undeclared-tax] of employers with [region =  25] end
to-report  undeclared26 report sum [undeclared-tax] of employers with [region =  26] end
to-report  undeclared27 report sum [undeclared-tax] of employers with [region =  27] end
to-report  undeclared28 report sum [undeclared-tax] of employers with [region =  28] end
to-report  undeclared29 report sum [undeclared-tax] of employers with [region =  29] end
to-report  undeclared30 report sum [undeclared-tax] of employers with [region =  30] end
to-report  undeclared31 report sum [undeclared-tax] of employers with [region =  31] end
to-report  undeclared32 report sum [undeclared-tax] of employers with [region =  32] end


;
to-report evasion-formal
  report sum [undeclared-tax] of employers with [mh_col = 1]
end

; Report types of taxpayer
to-report full-evasor
  report count employers with [type-of-taxpayer = 0] / count employers
end

to-report partial-compliant
  report count employers with [type-of-taxpayer = 1] / count employers
end

to-report compliant
  report count employers with [type-of-taxpayer = 2] / count employers
end
; ratio of compliants by state
to-report compliant01 report count employers with [type-of-taxpayer = 2 and region = 1] / count employers with [region = 1] end
to-report compliant02 report count employers with [type-of-taxpayer = 2 and region = 2] / count employers with [region = 2] end
to-report compliant03 report count employers with [type-of-taxpayer = 2 and region = 3] / count employers with [region = 3] end
to-report compliant04 report count employers with [type-of-taxpayer = 2 and region = 4] / count employers with [region = 4] end
to-report compliant05 report count employers with [type-of-taxpayer = 2 and region = 5] / count employers with [region = 5] end
to-report compliant06 report count employers with [type-of-taxpayer = 2 and region = 6] / count employers with [region = 6] end
to-report compliant07 report count employers with [type-of-taxpayer = 2 and region = 7] / count employers with [region = 7] end
to-report compliant08 report count employers with [type-of-taxpayer = 2 and region = 8] / count employers with [region = 8] end
to-report compliant09 report count employers with [type-of-taxpayer = 2 and region = 9] / count employers with [region = 9] end
to-report compliant10 report count employers with [type-of-taxpayer = 2 and region = 10] / count employers with [region = 10] end
to-report compliant11 report count employers with [type-of-taxpayer = 2 and region = 11] / count employers with [region = 11] end
to-report compliant12 report count employers with [type-of-taxpayer = 2 and region = 12] / count employers with [region = 12] end
to-report compliant13 report count employers with [type-of-taxpayer = 2 and region = 13] / count employers with [region = 13] end
to-report compliant14 report count employers with [type-of-taxpayer = 2 and region = 14] / count employers with [region = 14] end
to-report compliant15 report count employers with [type-of-taxpayer = 2 and region = 15] / count employers with [region = 15] end
to-report compliant16 report count employers with [type-of-taxpayer = 2 and region = 16] / count employers with [region = 16] end
to-report compliant17 report count employers with [type-of-taxpayer = 2 and region = 17] / count employers with [region = 17] end
to-report compliant18 report count employers with [type-of-taxpayer = 2 and region = 18] / count employers with [region = 18] end
to-report compliant19 report count employers with [type-of-taxpayer = 2 and region = 19] / count employers with [region = 19] end
to-report compliant20 report count employers with [type-of-taxpayer = 2 and region = 20] / count employers with [region = 20] end
to-report compliant21 report count employers with [type-of-taxpayer = 2 and region = 21] / count employers with [region = 21] end
to-report compliant22 report count employers with [type-of-taxpayer = 2 and region = 22] / count employers with [region = 22] end
to-report compliant23 report count employers with [type-of-taxpayer = 2 and region = 23] / count employers with [region = 23] end
to-report compliant24 report count employers with [type-of-taxpayer = 2 and region = 24] / count employers with [region = 24] end
to-report compliant25 report count employers with [type-of-taxpayer = 2 and region = 25] / count employers with [region = 25] end
to-report compliant26 report count employers with [type-of-taxpayer = 2 and region = 26] / count employers with [region = 26] end
to-report compliant27 report count employers with [type-of-taxpayer = 2 and region = 27] / count employers with [region = 27] end
to-report compliant28 report count employers with [type-of-taxpayer = 2 and region = 28] / count employers with [region = 28] end
to-report compliant29 report count employers with [type-of-taxpayer = 2 and region = 29] / count employers with [region = 29] end
to-report compliant30 report count employers with [type-of-taxpayer = 2 and region = 30] / count employers with [region = 30] end
to-report compliant31 report count employers with [type-of-taxpayer = 2 and region = 31] / count employers with [region = 31] end
to-report compliant32 report count employers with [type-of-taxpayer = 2 and region = 32] / count employers with [region = 32] end



to-report taxes-collected
  report sum [tax-collected] of auditors
end

; Taxes collected by state
to-report  taxes01 report sum [tax-collected] of auditors with [ent-auditor = 1] end
to-report  taxes02 report sum [tax-collected] of auditors with [ent-auditor = 2] end
to-report  taxes03 report sum [tax-collected] of auditors with [ent-auditor = 3] end
to-report  taxes04 report sum [tax-collected] of auditors with [ent-auditor = 4] end
to-report  taxes05 report sum [tax-collected] of auditors with [ent-auditor = 5] end
to-report  taxes06 report sum [tax-collected] of auditors with [ent-auditor = 6] end
to-report  taxes07 report sum [tax-collected] of auditors with [ent-auditor = 7] end
to-report  taxes08 report sum [tax-collected] of auditors with [ent-auditor = 8] end
to-report  taxes09 report sum [tax-collected] of auditors with [ent-auditor = 9] end
to-report  taxes10 report sum [tax-collected] of auditors with [ent-auditor = 10] end
to-report  taxes11 report sum [tax-collected] of auditors with [ent-auditor = 11] end
to-report  taxes12 report sum [tax-collected] of auditors with [ent-auditor = 12] end
to-report  taxes13 report sum [tax-collected] of auditors with [ent-auditor = 13] end
to-report  taxes14 report sum [tax-collected] of auditors with [ent-auditor = 14] end
to-report  taxes15 report sum [tax-collected] of auditors with [ent-auditor = 15] end
to-report  taxes16 report sum [tax-collected] of auditors with [ent-auditor = 16] end
to-report  taxes17 report sum [tax-collected] of auditors with [ent-auditor = 17] end
to-report  taxes18 report sum [tax-collected] of auditors with [ent-auditor = 18] end
to-report  taxes19 report sum [tax-collected] of auditors with [ent-auditor = 19] end
to-report  taxes20 report sum [tax-collected] of auditors with [ent-auditor = 20] end
to-report  taxes21 report sum [tax-collected] of auditors with [ent-auditor = 21] end
to-report  taxes22 report sum [tax-collected] of auditors with [ent-auditor = 22] end
to-report  taxes23 report sum [tax-collected] of auditors with [ent-auditor = 23] end
to-report  taxes24 report sum [tax-collected] of auditors with [ent-auditor = 24] end
to-report  taxes25 report sum [tax-collected] of auditors with [ent-auditor = 25] end
to-report  taxes26 report sum [tax-collected] of auditors with [ent-auditor = 26] end
to-report  taxes27 report sum [tax-collected] of auditors with [ent-auditor = 27] end
to-report  taxes28 report sum [tax-collected] of auditors with [ent-auditor = 28] end
to-report  taxes29 report sum [tax-collected] of auditors with [ent-auditor = 29] end
to-report  taxes30 report sum [tax-collected] of auditors with [ent-auditor = 30] end
to-report  taxes31 report sum [tax-collected] of auditors with [ent-auditor = 31] end
to-report  taxes32 report sum [tax-collected] of auditors with [ent-auditor = 32] end


to-report penalties-collected
  report sum [penalty-collected] of auditors
end

; Penalties by state
to-report  penalties01 report sum [penalty-collected] of auditors with [ent-auditor = 1] end
to-report  penalties02 report sum [penalty-collected] of auditors with [ent-auditor = 2] end
to-report  penalties03 report sum [penalty-collected] of auditors with [ent-auditor = 3] end
to-report  penalties04 report sum [penalty-collected] of auditors with [ent-auditor = 4] end
to-report  penalties05 report sum [penalty-collected] of auditors with [ent-auditor = 5] end
to-report  penalties06 report sum [penalty-collected] of auditors with [ent-auditor = 6] end
to-report  penalties07 report sum [penalty-collected] of auditors with [ent-auditor = 7] end
to-report  penalties08 report sum [penalty-collected] of auditors with [ent-auditor = 8] end
to-report  penalties09 report sum [penalty-collected] of auditors with [ent-auditor = 9] end
to-report  penalties10 report sum [penalty-collected] of auditors with [ent-auditor = 10] end
to-report  penalties11 report sum [penalty-collected] of auditors with [ent-auditor = 11] end
to-report  penalties12 report sum [penalty-collected] of auditors with [ent-auditor = 12] end
to-report  penalties13 report sum [penalty-collected] of auditors with [ent-auditor = 13] end
to-report  penalties14 report sum [penalty-collected] of auditors with [ent-auditor = 14] end
to-report  penalties15 report sum [penalty-collected] of auditors with [ent-auditor = 15] end
to-report  penalties16 report sum [penalty-collected] of auditors with [ent-auditor = 16] end
to-report  penalties17 report sum [penalty-collected] of auditors with [ent-auditor = 17] end
to-report  penalties18 report sum [penalty-collected] of auditors with [ent-auditor = 18] end
to-report  penalties19 report sum [penalty-collected] of auditors with [ent-auditor = 19] end
to-report  penalties20 report sum [penalty-collected] of auditors with [ent-auditor = 20] end
to-report  penalties21 report sum [penalty-collected] of auditors with [ent-auditor = 21] end
to-report  penalties22 report sum [penalty-collected] of auditors with [ent-auditor = 22] end
to-report  penalties23 report sum [penalty-collected] of auditors with [ent-auditor = 23] end
to-report  penalties24 report sum [penalty-collected] of auditors with [ent-auditor = 24] end
to-report  penalties25 report sum [penalty-collected] of auditors with [ent-auditor = 25] end
to-report  penalties26 report sum [penalty-collected] of auditors with [ent-auditor = 26] end
to-report  penalties27 report sum [penalty-collected] of auditors with [ent-auditor = 27] end
to-report  penalties28 report sum [penalty-collected] of auditors with [ent-auditor = 28] end
to-report  penalties29 report sum [penalty-collected] of auditors with [ent-auditor = 29] end
to-report  penalties30 report sum [penalty-collected] of auditors with [ent-auditor = 30] end
to-report  penalties31 report sum [penalty-collected] of auditors with [ent-auditor = 31] end
to-report  penalties32 report sum [penalty-collected] of auditors with [ent-auditor = 32] end


to-report min-tax-collected
  report precision min [tax-collected + penalty-collected] of auditors 3
end

to-report max-tax-collected
  report precision max [tax-collected + penalty-collected] of auditors 3
end

to-report state-min-collected
  let state min-one-of auditors [tax-collected]
  report entidad [ent-auditor] of state
end

to-report state-max-collected
  let state max-one-of auditors [tax-collected]
  report entidad [ent-auditor] of state
end

to-report pct-informal-emp
  report 100 * ( count employers with [mh_col = 0] / count employers)
end
; percent of informal employers by state
to-report pctinformalemp01 report 100 * ( count employers with [mh_col = 0 and region = 1] / count employers with [region = 1]) end
to-report pctinformalemp02 report 100 * ( count employers with [mh_col = 0 and region = 2] / count employers with [region = 2]) end
to-report pctinformalemp03 report 100 * ( count employers with [mh_col = 0 and region = 3] / count employers with [region = 3]) end
to-report pctinformalemp04 report 100 * ( count employers with [mh_col = 0 and region = 4] / count employers with [region = 4]) end
to-report pctinformalemp05 report 100 * ( count employers with [mh_col = 0 and region = 5] / count employers with [region = 5]) end
to-report pctinformalemp06 report 100 * ( count employers with [mh_col = 0 and region = 6] / count employers with [region = 6]) end
to-report pctinformalemp07 report 100 * ( count employers with [mh_col = 0 and region = 7] / count employers with [region = 7]) end
to-report pctinformalemp08 report 100 * ( count employers with [mh_col = 0 and region = 8] / count employers with [region = 8]) end
to-report pctinformalemp09 report 100 * ( count employers with [mh_col = 0 and region = 9] / count employers with [region = 9]) end
to-report pctinformalemp10 report 100 * ( count employers with [mh_col = 0 and region = 10] / count employers with [region = 10]) end
to-report pctinformalemp11 report 100 * ( count employers with [mh_col = 0 and region = 11] / count employers with [region = 11]) end
to-report pctinformalemp12 report 100 * ( count employers with [mh_col = 0 and region = 12] / count employers with [region = 12]) end
to-report pctinformalemp13 report 100 * ( count employers with [mh_col = 0 and region = 13] / count employers with [region = 13]) end
to-report pctinformalemp14 report 100 * ( count employers with [mh_col = 0 and region = 14] / count employers with [region = 14]) end
to-report pctinformalemp15 report 100 * ( count employers with [mh_col = 0 and region = 15] / count employers with [region = 15]) end
to-report pctinformalemp16 report 100 * ( count employers with [mh_col = 0 and region = 16] / count employers with [region = 16]) end
to-report pctinformalemp17 report 100 * ( count employers with [mh_col = 0 and region = 17] / count employers with [region = 17]) end
to-report pctinformalemp18 report 100 * ( count employers with [mh_col = 0 and region = 18] / count employers with [region = 18]) end
to-report pctinformalemp19 report 100 * ( count employers with [mh_col = 0 and region = 19] / count employers with [region = 19]) end
to-report pctinformalemp20 report 100 * ( count employers with [mh_col = 0 and region = 20] / count employers with [region = 20]) end
to-report pctinformalemp21 report 100 * ( count employers with [mh_col = 0 and region = 21] / count employers with [region = 21]) end
to-report pctinformalemp22 report 100 * ( count employers with [mh_col = 0 and region = 22] / count employers with [region = 22]) end
to-report pctinformalemp23 report 100 * ( count employers with [mh_col = 0 and region = 23] / count employers with [region = 23]) end
to-report pctinformalemp24 report 100 * ( count employers with [mh_col = 0 and region = 24] / count employers with [region = 24]) end
to-report pctinformalemp25 report 100 * ( count employers with [mh_col = 0 and region = 25] / count employers with [region = 25]) end
to-report pctinformalemp26 report 100 * ( count employers with [mh_col = 0 and region = 26] / count employers with [region = 26]) end
to-report pctinformalemp27 report 100 * ( count employers with [mh_col = 0 and region = 27] / count employers with [region = 27]) end
to-report pctinformalemp28 report 100 * ( count employers with [mh_col = 0 and region = 28] / count employers with [region = 28]) end
to-report pctinformalemp29 report 100 * ( count employers with [mh_col = 0 and region = 29] / count employers with [region = 29]) end
to-report pctinformalemp30 report 100 * ( count employers with [mh_col = 0 and region = 30] / count employers with [region = 30]) end
to-report pctinformalemp31 report 100 * ( count employers with [mh_col = 0 and region = 31] / count employers with [region = 31]) end
to-report pctinformalemp32 report 100 * ( count employers with [mh_col = 0 and region = 32] / count employers with [region = 32]) end


to-report pct-GDP-informal
  report 100 * ( sum [production] of employers with [mh_col = 0] / sum [production] of employers)
end

to-report avg-age
  report mean [eda] of employers
end

; Abreviaturas en código ISO 3166-2
to-report entidad [reg]
  (ifelse
    reg =  1 [report "AG"]
    reg =  2 [report "BC"]
    reg =  3 [report "BS"]
    reg =  4 [report "CM"]
    reg =  5 [report "CO"]
    reg =  6 [report "CL"]
    reg =  7 [report "CS"]
    reg =  8 [report "CH"]
    reg =  9 [report "CX"]
    reg = 10 [report "DG"]
    reg = 11 [report "GT"]
    reg = 12 [report "GR"]
    reg = 13 [report "HG"]
    reg = 14 [report "JC"]
    reg = 15 [report "EM"]
    reg = 16 [report "MI"]
    reg = 17 [report "MO"]
    reg = 18 [report "NA"]
    reg = 19 [report "NL"]
    reg = 20 [report "OA"]
    reg = 21 [report "PU"]
    reg = 22 [report "QT"]
    reg = 23 [report "QR"]
    reg = 24 [report "SL"]
    reg = 25 [report "SI"]
    reg = 26 [report "SO"]
    reg = 27 [report "TB"]
    reg = 28 [report "TM"]
    reg = 29 [report "TL"]
    reg = 30 [report "VE"]
    reg = 31 [report "YU"]
    reg = 32 [report "ZA"]
  )
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
9
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
1247
376
1335
421
No. employers
count employers
0
1
11

MONITOR
1012
376
1176
421
GDP of informal economy (%)
pct-GDP-informal
2
1
11

CHOOSER
9
46
178
91
scale-for-number-of-employers
scale-for-number-of-employers
"1:2,000" "1:3,000" "1:4,000" "1:5,000" "test"
0

PLOT
1247
11
1482
131
Distribution of payroll
$
Freq
0.0
10.0
0.0
10.0
true
false
"set-plot-x-range 0 round max [payroll] of employers\nset-plot-y-range 0 sqrt count employers\nset-histogram-num-bars sqrt count employers\nset-plot-pen-mode 1\nset-plot-pen-color 1\nhistogram [payroll] of employers" ""
PENS
"pen-0" 1.0 0 -7500403 true "" ""

PLOT
1247
133
1482
253
Age distribution
Age
Freq
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
15
446
128
479
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
1336
376
1482
421
% of informal employers
pct-informal-emp
2
1
11

SLIDER
9
146
129
179
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
9
183
129
216
α
α
0
1
0.05
0.01
1
NIL
HORIZONTAL

PLOT
1247
254
1482
374
Probability of become formal
Prob (Y= Formal)
Freq
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
12
241
127
274
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
12
224
162
242
Effectiveness of
11
0.0
1

TEXTBOX
137
251
250
269
Audit process
11
0.0
1

SLIDER
12
277
127
310
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
136
287
251
305
Tax collection
11
0.0
1

PLOT
753
11
1011
131
The Extent of Tax Evasion
month
Ratio
0.0
10.0
0.0
10.0
true
true
"set-plot-x-range 0 120\nset-plot-y-range 0 0.3" ""
PENS
"Total" 1.0 0 -7500403 true "" "plot ETE"
"Formal" 1.0 0 -13345367 true "" "plot ETE-formal"

PLOT
1012
133
1246
253
Collected penalties
month
$
0.0
10.0
0.0
10.0
true
false
"set-plot-x-range 0 120\nset-plot-y-range 0 1" ""
PENS
"Penalties" 1.0 0 -5298144 true "" "plot penalties-collected"

PLOT
1012
11
1246
131
Collected tax
month
$
0.0
10.0
0.0
10.0
true
false
"set-plot-x-range 0 120" ""
PENS
"default" 1.0 0 -13345367 true "" "plot taxes-collected"

TEXTBOX
12
319
162
337
decrease / increase 
11
0.0
1

SLIDER
15
338
128
371
Δθ
Δθ
-3
3
0.0
0.5
1
%
HORIZONTAL

SLIDER
15
374
128
407
ΔPI
ΔPI
-15
15
15.0
1
1
%
HORIZONTAL

TEXTBOX
137
348
250
366
Tax rate
11
0.0
1

TEXTBOX
137
384
249
406
Perceived insecurity\n
11
0.0
1

TEXTBOX
11
129
161
147
Fiscal environment
11
0.0
1

TEXTBOX
138
156
250
174
Penalty rate
11
0.0
1

TEXTBOX
138
193
250
211
Audit probability
11
0.0
1

SLIDER
15
410
128
443
ΔPC
ΔPC
-15
15
0.0
1
1
%
HORIZONTAL

TEXTBOX
137
420
251
438
Perceived corruption
11
0.0
1

TEXTBOX
137
451
251
479
Decision threshold\nto be in formal sector
11
0.0
1

TEXTBOX
272
432
399
460
Visualization \noptions
11
0.0
1

CHOOSER
338
427
476
472
color-palette
color-palette
"viridis" "inferno" "magma" "plasma" "cividis" "parula" "turbo"
3

SWITCH
479
427
614
460
Abbrev-states
Abbrev-states
0
1
-1000

PLOT
753
133
1011
253
Undeclared tax
month
$
0.0
10.0
0.0
10.0
true
true
"set-plot-x-range 0 120\nset-plot-y-range 0 1" ""
PENS
"Total" 1.0 0 -7500403 true "" "plot evasion"
"Formal" 1.0 0 -13345367 true "" "plot evasion-formal"

PLOT
753
254
1011
374
Types of taxpayer
Month
Ratio
0.0
10.0
0.0
10.0
true
true
"set-plot-x-range 0 120\nset-plot-y-range 0 precision 0.5 1" ""
PENS
"Evasor" 1.0 0 -5298144 true "" "plot full-evasor"
"Partial" 1.0 0 -11221820 true "" "plot partial-compliant"
"Compliant" 1.0 0 -13345367 true "" "plot compliant"

PLOT
1012
254
1246
374
Number of audits
Month
NIL
0.0
10.0
0.0
10.0
true
false
"set-plot-x-range 0 120\nset-plot-y-range 0 1" ""
PENS
"default" 1.0 0 -16777216 true "" "plot audits"

MONITOR
1177
376
1246
421
Avg. Age
avg-age
0
1
11

MONITOR
852
376
931
421
Lower
(word  state-min-collected \": $ \" min-tax-collected)
0
1
11

TEXTBOX
756
377
853
419
States with the lowest and highest tax collections
11
0.0
1

MONITOR
932
376
1011
421
Higher
(word  state-max-collected \": $ \" max-tax-collected)
0
1
11

SWITCH
9
93
178
126
machine-learning?
machine-learning?
1
1
-1000

@#$#@#$#@
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

```R
install.packages("rJava")
install.packages("ranger")
install.packages("readr")
```

#### Netlogo
Configure the R extention appropriately. 

### ODD protocol
For the sake of reproducibility, the details of the model will be described following the ODD protocol (Grimm et al., 2010), which is organized in three parts:

1.  **Overview**. A general description of the model, including its purpose and its basic components: agents, variables describing them and the environment, and scales used in the model, e.g., time and space; as well as a processes overview and their scheduling.

2.  **Design concepts**. A brief description of the basic principles underlying the model's design, e.g., rationality, emergence, adaptation, learning, etc.

3.  **Details**. Full definitions of the involved submodels.

#### Overview
##### Purpose
Analyze the effect of institutional determinants on payroll tax evasion in Mexico.

##### Entities, state variables, and scales
-   Agents: Employers and tax authority.
-   Environment: A Mexican state-level representation of the payroll tax system.
-   Scales: Time is represented in discrete periods, each step representing a month, which corresponds to the tax collection period according to the current legislation. In order to have a margin of error less than 5% with a confidence interval of 99% in the selected sample, each employer agent in the model represents 2,000 employers in the 2019 Mexican labor market.
-   State variables: The attributes that characterize each agent are shown in Table 1.

<table>
<thead>
<tr>
<th>Agent</th>
<th>Type</th>
<th>Attributes</th>
</tr>
</thead>
<tbody>
<tr>
<td>Auditor</td>
<td><code>Agset</code></td>
<td>employers-of-auditor</td>
</tr>
<tr>
<td>Auditor</td>
<td><code>Float</code></td>
<td>penalty-collected; tax-collected</td>
</tr>
<tr>
<td>Auditor</td>
<td><code>Int</code></td>
<td>ent-auditor</td>
</tr>
<tr>
<td>Employer</td>
<td><code>Bool</code></td>
<td>audit?; audited?; formal-or-informal (mh_col)</td>
</tr>
<tr>
<td>Employer</td>
<td><code>Float</code></td>
<td>corruption; declared-tax; insecurity; payroll; payroll*; prob-formal; production; risk-aversion-ρ; tax; undeclared-payroll; undeclared-tax; <img src="https://latex.codecogs.com/gif.image?\alpha_S" alt="eqn-27">; <img src="https://latex.codecogs.com/gif.image?\delta" alt="eqn-27"></td>
</tr>
<tr>
<td>Employer</td>
<td><code>Int</code></td>
<td>eda (age); business-size (ambito2); education (anios_esc); economic-activity (c_ocu11c); state (ent); income (ing7c); size-of-region (t_loc); type-of-taxpayer</td>
</tr>
</tbody>
</table>


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

The dataset collected in this way, gives a matrix of size ![eqn](https://latex.codecogs.com/gif.image?71833\times{10}), where the proportion of formal employers is 60.57%. A fast implementation of Random Forest was chosen to learn from data because it provides a fast model fitting and evaluating, is robust to outliers, can deal with simple linear and complicated nonlinear associations, and produces competitive prediction accuracy. To tune the hyperparameters and evaluate the performance of the model, a cross-validation with *10* folds was carried out. The final hyperparameters values were *mtry=20*, *ntrees=100*, and *nodesize = 1*. That setting gets an accuracy of 83.79%, which is considered good to avoid overfitting. The trained model will be available to employers during the simulation.

From the resulting preprocessed ENOE data a sampling is performed using the local pivot method, which effectively generates a balanced sample data set. Selected attributes to generate the balanced sample were the state, the employer's classification by belonging to the formal or informal sector, and the size of the employer's economic unit. This ensures that the employers in the model reflect the actual proportions of the Mexican labor market. The size of the selected sample corresponds to the scale 1 to 2000.
At time ![eqn](https://latex.codecogs.com/gif.image?t=0), of every simulation run, ![eqn](https://latex.codecogs.com/gif.image?N=1337) employers are initialized and distributed on each state according to the sample dataset. 32 auditors are also initialized representing each state tax authority. Some state variables are initialized by a submodel, either deterministic or random, while some others are based on data as shown in Table 2.

<table>
<thead>
<tr>
<th>Agent</th>
<th>Initialization</th>
<th>Attributes</th>
</tr>
</thead>
<tbody>
<tr>
<td>Auditor</td>
<td>Deterministic</td>
<td>penalty-collected; tax-collected</td>
</tr>
<tr>
<td>Auditor</td>
<td>Random</td>
<td>ent-auditor; my-employers</td>
</tr>
<tr>
<td>Employer</td>
<td>Data base</td>
<td>ambito2; anios_esc; c_ocu11c; corruption; eda; ent; ing7c; insecurity; mh_col; t_loc; tax</td>
</tr>
<tr>
<td>Employer</td>
<td>Deterministic</td>
<td>audit?; audited?; declared-tax; payroll; payroll*; risk-aversion-ρ; type-of-taxpayer; undeclared-payroll; undeclared-tax; <img src="https://latex.codecogs.com/gif.image?\alpha_S" alt="eqn-27">; <img src="https://latex.codecogs.com/gif.image?\delta" alt="eqn-27"></td>
</tr>
<tr>
<td>Employer</td>
<td>Random</td>
<td>prob-formal; production</td>
</tr>
</tbody>
</table>

**Table 2**: Initialization of state variables.

In the same way, input parameters of simulation were adopted from literature, data base or through experimentation. Table 3 shows the initial values of the baseline model. The user interface also has other input parameters, one of them allows to switch “on” and “off” the machine learning model.

<table>
<thead>
<tr>
<th>Parameter</th>
<th>Description</th>
<th>Value</th>
<th>Initialization</th>
</tr>
</thead>
<tbody>
<tr>
<td><img src="https://latex.codecogs.com/gif.image?\pi" alt="eqn-27"></td>
<td>Penalty rate</td>
<td>0.75</td>
<td>Data base</td>
</tr>
<tr>
<td><img src="https://latex.codecogs.com/gif.image?\alpha" alt="eqn-27"></td>
<td>Audit probability</td>
<td>0.05</td>
<td>Experimentation</td>
</tr>
<tr>
<td><img src="https://latex.codecogs.com/gif.image?\epsilon_{AP}" alt="eqn-27"></td>
<td>Effectiveness of audit process</td>
<td>0.75</td>
<td>Experimentation</td>
</tr>
<tr>
<td><img src="https://latex.codecogs.com/gif.image?\epsilon_{TC}" alt="eqn-27"></td>
<td>Effectiveness of tax collection</td>
<td>0.7</td>
<td>Literature</td>
</tr>
<tr>
<td><img src="https://latex.codecogs.com/gif.image?\Delta\theta" alt="eqn-27"></td>
<td>Variation in tax rate</td>
<td>0</td>
<td>Data base</td>
</tr>
<tr>
<td><img src="https://latex.codecogs.com/gif.image?\Delta{PI}" alt="eqn-27"></td>
<td>Variation in perceived insecurity</td>
<td>0</td>
<td>Data base</td>
</tr>
<tr>
<td><img src="https://latex.codecogs.com/gif.image?\Delta{PC}" alt="eqn-27"></td>
<td>Variation in perceived corruption</td>
<td>0</td>
<td>Data base</td>
</tr>
<tr>
<td><img src="https://latex.codecogs.com/gif.image?\tau" alt="eqn-27"></td>
<td>Threshold for formal or informal sector choice</td>
<td>0.5</td>
<td>Literature</td>
</tr>
</tbody>
</table>

**Table 3**: Input parameter initialization of baseline model.

##### Input data
The model does not use input data to represent time-varying processes.

##### Submodels
1. A Geographical Information System layer is loaded. Each polygon is a hexagonal tessellation of the corresponding Mexican state.

2. ![eqn](https://latex.codecogs.com/gif.image?N=1337) employers are generated and initialized with information of the data base and moved to their corresponding state.

3. Auditors are generated and located to their assigned state.

4. The a priori learned random forest model is loaded.

5. Generate pareto-law values with the following distribution function
   ![eqn-5](https://latex.codecogs.com/gif.image?f(x)~x^{-1-\gamma})

6. Where ![eqn](https://latex.codecogs.com/gif.image?\gamma) is known as the Pareto exponent and estimated to be ![eqn](https://latex.codecogs.com/gif.image?\approx{3/2}) to characterize a capitalist economy.

7. ![eqn](https://latex.codecogs.com/gif.image?x)  are the values generated by a normal distribution function with mean ![eqn](https://latex.codecogs.com/gif.image?\mu=2) and standard deviation ![eqn](https://latex.codecogs.com/gif.image?\sigma^2=0.2) for informal employers and ![eqn](https://latex.codecogs.com/gif.image?\sigma^2=0.3) for the formal ones.

8. To assign a fixed monthly production value to each employer. Generated power law values are multiplied by 23 in the case of informal employers and 50 for the formal. Those quantities generate a perfectly mixed Pareto distribution according to the basic principles and preserve the participation of the informal economy in Mexican GDP.

9. For simplicity, it is assumed that each employer allocates 30 percent of the value of production to payroll ![eqn](https://latex.codecogs.com/gif.image?W). The share of wages in Mexican GDP is between 30 and 40%.

10. At the beginning of the simulation, it is assumed that non-informal employers declare all the tax, declared payroll ![eqn-10](https://latex.codecogs.com/gif.image?W^{*}=W)

11. At the beginning declared tax ![eqn-10](https://latex.codecogs.com/gif.image?X^{*}) by each employer is equal to the declared payroll ![eqn-10](https://latex.codecogs.com/gif.image?W^{*}) multiplied by the tax rate ![eqn-10](https://latex.codecogs.com/gif.image?\theta) in their state.

12. Each 12 periods (months) employers increase their age, and they consult the learned model to decide whether to opt for the formal or informal market, taking their internal attributes and perceived insecurity as a reference.

13. Informal employers do not declare taxes.

14. By social norm, employers modify their risk aversion ![eqn-13](https://latex.codecogs.com/gif.image?\rho) according to their age as follows:
![eqn-14](./eqns/Eqn14a.gif)

15. Let ![eqn-15](https://latex.codecogs.com/gif.image?\beta) the perceived public goods efficiency, and ![eqn-15](https://latex.codecogs.com/gif.image?\pi) the penalty rate.

16. Let ![eqn-16](https://latex.codecogs.com/gif.image?\epsilon_{AP}) and  ![eqn-16](https://latex.codecogs.com/gif.image?\epsilon_{TC}) the effectiveness of audit process and tax collection respectively.

17. Let ![eqn-17](https://latex.codecogs.com/gif.image?\alpha) the true audit probability and ![eqn-17](https://latex.codecogs.com/gif.image?\alpha_S) the subjective audit probability known to the employer.

18. Let ![eqn-18](https://latex.codecogs.com/gif.image?\delta=0.1), the updating parameter for ![eqn-18](https://latex.codecogs.com/gif.image?\alpha_S).

19. If an employer is audited in a specific period, subjective audit probability becomes ![eqn](https://latex.codecogs.com/gif.image?1).

20. In each period (if not audited again) ![eqn-20](https://latex.codecogs.com/gif.image?\alpha_S) decreases in ![eqn-20](https://latex.codecogs.com/gif.image?\delta) amount until ![eqn-20](https://latex.codecogs.com/gif.image?\alpha_S=\alpha).

21. Each period, employers calculate the amount of taxes to declare voluntarily ![eqn-21](https://latex.codecogs.com/gif.image?X^*), applying the expected utility maximization procedure adopted by Allingham and Sandmo (1972). Let lower bound:
![eqn-21](./eqns/Eqn21a.gif)
22. And the upper bound:
![eqn-22](./eqns/Eqn22a.gif)

23. If the subjective audit probability ![eqn-23](https://latex.codecogs.com/gif.image?\alpha_S) exceeds the upper limit in submodel 22, employer becomes fully tax compliant, that is, ![eqn-23](https://latex.codecogs.com/gif.image?X^{*}=W\theta), and when ![eqn-23](https://latex.codecogs.com/gif.image?\alpha_S) falls below the lower bound in submodel 21, the employer fully evades, that is ![eqn-23](https://latex.codecogs.com/gif.image?X^{*}=0).

24. For ![eqn-24](https://latex.codecogs.com/gif.image?\alpha_S) in the range for an inner solution, employer voluntarily declares:
    ![eqn-24](./eqns/Eqn24a.gif)

25. The tax authority collects payroll taxes that employers voluntarily declared.

26. The tax authority carries out audits with a random probability of α and a level of effectiveness ![eqn-26](https://latex.codecogs.com/gif.image?\epsilon_{AP}).

27. If an evader is detected the undeclared tax is collected and a penalty rate ![eqn-27](https://latex.codecogs.com/gif.image?\pi) is applied over the undeclared tax.

28. In each period, employers have a probability of dying, following a Weibull quantile derivation function:

    ![eqn-28](https://latex.codecogs.com/gif.image?Q(p)=\lambda\left[\frac{1}{1-p}\right]^{\frac{1}{k}})

29. Where ![eqn-29](https://latex.codecogs.com/gif.image?\lambda=0.019) and ![eqn-29](https://latex.codecogs.com/gif.image?k=0.479) are the scale and shape parameter respectively.

30. It is assumed that when an employer dies, someone else takes their place with the same attributes, except for age, which is generated according to:
![eqn-30](https://latex.codecogs.com/gif.image?eda=\lfloor{X}\rfloor)
![eqn-30](https://latex.codecogs.com/gif.image?%5Cdpi%7B110%7D%20X%5Csim%7BN%7D(%5Cmu,%5Csigma%5E%7B2%7D)%5Csim%7BN%7D(37,6))

31. At each time ![eqn-31](https://latex.codecogs.com/gif.image?t), the observed output Extent of Tax Evasion is calculated as follows:

    ![eqn-31](https://latex.codecogs.com/gif.image?ETE_t=1-\frac{\sum_{i=1}^{N}W^{*}}{\sum_{i=1}^{N}W})

### References
-    J. Alm, (2011). «Measuring, explaining, and controlling tax evasion: lessons from theory, experiments, and field studies,» *International Tax and Public Finance*, pp. 54-77.
-    S. Hokamp, (2014). «Dynamics of tax evasion with back auditing, social norm updating, and public goods provision - An agent-based simulation,» *Journal of Economic Psychology,* pp. 187-199.
-    M. G. Allingham y A. Sandmo, (1972). «Income tax evasion: a theoretical analysis,» *Journal of Public Economics,* pp. 323-338.
-   V. Grimm, U. Berger, D. L. DeAngelis, J. G. Polhill, J. Giske y S. F. Railsback, (2010). «The ODD protocol: A review and first update,» *Ecological Modelling,* pp. 2760-2768.
-   A. Chakraborti & M. Patriarca, (2008). «Gamma-distribution and wealth inequality,» *Journal of physics,* pp. 233-243.
-   J. E. Pinder, J. G. Wiener y M. H. Smith, (1978). «The Weibull Distribution: A New Method of Summarizing Survivorship Data,» *Ecology,* pp. 175-179.
-   CONAPO, (2020). «Datos Abiertos. Indicadores demográficos 1950 - 2050.,» Consejo Nacional de Población, Ciudad de México.
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
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="35"/>
    <metric>ETE</metric>
    <metric>ETE-formal</metric>
    <metric>taxes-collected</metric>
    <metric>penalties-collected</metric>
    <metric>evasion</metric>
    <metric>evasion-formal</metric>
    <metric>full-evasor</metric>
    <metric>partial-compliant</metric>
    <metric>compliant</metric>
    <metric>pct-GDP-informal</metric>
    <metric>pct-informal-emp</metric>
    <metric>min-tax-collected</metric>
    <metric>max-tax-collected</metric>
    <metric>ETE01</metric>
    <metric>ETE02</metric>
    <metric>ETE03</metric>
    <metric>ETE04</metric>
    <metric>ETE05</metric>
    <metric>ETE06</metric>
    <metric>ETE07</metric>
    <metric>ETE08</metric>
    <metric>ETE09</metric>
    <metric>ETE10</metric>
    <metric>ETE11</metric>
    <metric>ETE12</metric>
    <metric>ETE13</metric>
    <metric>ETE14</metric>
    <metric>ETE15</metric>
    <metric>ETE16</metric>
    <metric>ETE17</metric>
    <metric>ETE18</metric>
    <metric>ETE19</metric>
    <metric>ETE20</metric>
    <metric>ETE21</metric>
    <metric>ETE22</metric>
    <metric>ETE23</metric>
    <metric>ETE24</metric>
    <metric>ETE25</metric>
    <metric>ETE26</metric>
    <metric>ETE27</metric>
    <metric>ETE28</metric>
    <metric>ETE29</metric>
    <metric>ETE30</metric>
    <metric>ETE31</metric>
    <metric>ETE32</metric>
    <metric>undeclared01</metric>
    <metric>undeclared02</metric>
    <metric>undeclared03</metric>
    <metric>undeclared04</metric>
    <metric>undeclared05</metric>
    <metric>undeclared06</metric>
    <metric>undeclared07</metric>
    <metric>undeclared08</metric>
    <metric>undeclared09</metric>
    <metric>undeclared10</metric>
    <metric>undeclared11</metric>
    <metric>undeclared12</metric>
    <metric>undeclared13</metric>
    <metric>undeclared14</metric>
    <metric>undeclared15</metric>
    <metric>undeclared16</metric>
    <metric>undeclared17</metric>
    <metric>undeclared18</metric>
    <metric>undeclared19</metric>
    <metric>undeclared20</metric>
    <metric>undeclared21</metric>
    <metric>undeclared22</metric>
    <metric>undeclared23</metric>
    <metric>undeclared24</metric>
    <metric>undeclared25</metric>
    <metric>undeclared26</metric>
    <metric>undeclared27</metric>
    <metric>undeclared28</metric>
    <metric>undeclared29</metric>
    <metric>undeclared30</metric>
    <metric>undeclared31</metric>
    <metric>undeclared32</metric>
    <metric>taxes01</metric>
    <metric>taxes02</metric>
    <metric>taxes03</metric>
    <metric>taxes04</metric>
    <metric>taxes05</metric>
    <metric>taxes06</metric>
    <metric>taxes07</metric>
    <metric>taxes08</metric>
    <metric>taxes09</metric>
    <metric>taxes10</metric>
    <metric>taxes11</metric>
    <metric>taxes12</metric>
    <metric>taxes13</metric>
    <metric>taxes14</metric>
    <metric>taxes15</metric>
    <metric>taxes16</metric>
    <metric>taxes17</metric>
    <metric>taxes18</metric>
    <metric>taxes19</metric>
    <metric>taxes20</metric>
    <metric>taxes21</metric>
    <metric>taxes22</metric>
    <metric>taxes23</metric>
    <metric>taxes24</metric>
    <metric>taxes25</metric>
    <metric>taxes26</metric>
    <metric>taxes27</metric>
    <metric>taxes28</metric>
    <metric>taxes29</metric>
    <metric>taxes30</metric>
    <metric>taxes31</metric>
    <metric>taxes32</metric>
    <metric>penalties01</metric>
    <metric>penalties02</metric>
    <metric>penalties03</metric>
    <metric>penalties04</metric>
    <metric>penalties05</metric>
    <metric>penalties06</metric>
    <metric>penalties07</metric>
    <metric>penalties08</metric>
    <metric>penalties09</metric>
    <metric>penalties10</metric>
    <metric>penalties11</metric>
    <metric>penalties12</metric>
    <metric>penalties13</metric>
    <metric>penalties14</metric>
    <metric>penalties15</metric>
    <metric>penalties16</metric>
    <metric>penalties17</metric>
    <metric>penalties18</metric>
    <metric>penalties19</metric>
    <metric>penalties20</metric>
    <metric>penalties21</metric>
    <metric>penalties22</metric>
    <metric>penalties23</metric>
    <metric>penalties24</metric>
    <metric>penalties25</metric>
    <metric>penalties26</metric>
    <metric>penalties27</metric>
    <metric>penalties28</metric>
    <metric>penalties29</metric>
    <metric>penalties30</metric>
    <metric>penalties31</metric>
    <metric>penalties32</metric>
    <metric>pctinformalemp01</metric>
    <metric>pctinformalemp02</metric>
    <metric>pctinformalemp03</metric>
    <metric>pctinformalemp04</metric>
    <metric>pctinformalemp05</metric>
    <metric>pctinformalemp06</metric>
    <metric>pctinformalemp07</metric>
    <metric>pctinformalemp08</metric>
    <metric>pctinformalemp09</metric>
    <metric>pctinformalemp10</metric>
    <metric>pctinformalemp11</metric>
    <metric>pctinformalemp12</metric>
    <metric>pctinformalemp13</metric>
    <metric>pctinformalemp14</metric>
    <metric>pctinformalemp15</metric>
    <metric>pctinformalemp16</metric>
    <metric>pctinformalemp17</metric>
    <metric>pctinformalemp18</metric>
    <metric>pctinformalemp19</metric>
    <metric>pctinformalemp20</metric>
    <metric>pctinformalemp21</metric>
    <metric>pctinformalemp22</metric>
    <metric>pctinformalemp23</metric>
    <metric>pctinformalemp24</metric>
    <metric>pctinformalemp25</metric>
    <metric>pctinformalemp26</metric>
    <metric>pctinformalemp27</metric>
    <metric>pctinformalemp28</metric>
    <metric>pctinformalemp29</metric>
    <metric>pctinformalemp30</metric>
    <metric>pctinformalemp31</metric>
    <metric>pctinformalemp32</metric>
    <metric>compliant01</metric>
    <metric>compliant02</metric>
    <metric>compliant03</metric>
    <metric>compliant04</metric>
    <metric>compliant05</metric>
    <metric>compliant06</metric>
    <metric>compliant07</metric>
    <metric>compliant08</metric>
    <metric>compliant09</metric>
    <metric>compliant10</metric>
    <metric>compliant11</metric>
    <metric>compliant12</metric>
    <metric>compliant13</metric>
    <metric>compliant14</metric>
    <metric>compliant15</metric>
    <metric>compliant16</metric>
    <metric>compliant17</metric>
    <metric>compliant18</metric>
    <metric>compliant19</metric>
    <metric>compliant20</metric>
    <metric>compliant21</metric>
    <metric>compliant22</metric>
    <metric>compliant23</metric>
    <metric>compliant24</metric>
    <metric>compliant25</metric>
    <metric>compliant26</metric>
    <metric>compliant27</metric>
    <metric>compliant28</metric>
    <metric>compliant29</metric>
    <metric>compliant30</metric>
    <metric>compliant31</metric>
    <metric>compliant32</metric>
    <enumeratedValueSet variable="π">
      <value value="0.15"/>
      <value value="0.2"/>
      <value value="0.25"/>
      <value value="0.3"/>
      <value value="0.35"/>
      <value value="0.36"/>
      <value value="0.37"/>
      <value value="0.38"/>
      <value value="0.39"/>
      <value value="0.4"/>
      <value value="0.41"/>
      <value value="0.42"/>
      <value value="0.43"/>
      <value value="0.44"/>
      <value value="0.45"/>
      <value value="0.5"/>
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Δθ">
      <value value="-1"/>
      <value value="-0.8"/>
      <value value="-0.6"/>
      <value value="-0.5"/>
      <value value="-0.4"/>
      <value value="-0.3"/>
      <value value="-0.2"/>
      <value value="-0.1"/>
      <value value="0"/>
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.3"/>
      <value value="0.4"/>
      <value value="0.5"/>
      <value value="0.6"/>
      <value value="0.8"/>
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="35"/>
    <metric>ETE</metric>
    <metric>ETE-formal</metric>
    <metric>taxes-collected</metric>
    <metric>penalties-collected</metric>
    <metric>evasion</metric>
    <metric>evasion-formal</metric>
    <metric>full-evasor</metric>
    <metric>partial-compliant</metric>
    <metric>compliant</metric>
    <metric>pct-GDP-informal</metric>
    <metric>pct-informal-emp</metric>
    <metric>min-tax-collected</metric>
    <metric>max-tax-collected</metric>
    <metric>ETE01</metric>
    <metric>ETE02</metric>
    <metric>ETE03</metric>
    <metric>ETE04</metric>
    <metric>ETE05</metric>
    <metric>ETE06</metric>
    <metric>ETE07</metric>
    <metric>ETE08</metric>
    <metric>ETE09</metric>
    <metric>ETE10</metric>
    <metric>ETE11</metric>
    <metric>ETE12</metric>
    <metric>ETE13</metric>
    <metric>ETE14</metric>
    <metric>ETE15</metric>
    <metric>ETE16</metric>
    <metric>ETE17</metric>
    <metric>ETE18</metric>
    <metric>ETE19</metric>
    <metric>ETE20</metric>
    <metric>ETE21</metric>
    <metric>ETE22</metric>
    <metric>ETE23</metric>
    <metric>ETE24</metric>
    <metric>ETE25</metric>
    <metric>ETE26</metric>
    <metric>ETE27</metric>
    <metric>ETE28</metric>
    <metric>ETE29</metric>
    <metric>ETE30</metric>
    <metric>ETE31</metric>
    <metric>ETE32</metric>
    <metric>undeclared01</metric>
    <metric>undeclared02</metric>
    <metric>undeclared03</metric>
    <metric>undeclared04</metric>
    <metric>undeclared05</metric>
    <metric>undeclared06</metric>
    <metric>undeclared07</metric>
    <metric>undeclared08</metric>
    <metric>undeclared09</metric>
    <metric>undeclared10</metric>
    <metric>undeclared11</metric>
    <metric>undeclared12</metric>
    <metric>undeclared13</metric>
    <metric>undeclared14</metric>
    <metric>undeclared15</metric>
    <metric>undeclared16</metric>
    <metric>undeclared17</metric>
    <metric>undeclared18</metric>
    <metric>undeclared19</metric>
    <metric>undeclared20</metric>
    <metric>undeclared21</metric>
    <metric>undeclared22</metric>
    <metric>undeclared23</metric>
    <metric>undeclared24</metric>
    <metric>undeclared25</metric>
    <metric>undeclared26</metric>
    <metric>undeclared27</metric>
    <metric>undeclared28</metric>
    <metric>undeclared29</metric>
    <metric>undeclared30</metric>
    <metric>undeclared31</metric>
    <metric>undeclared32</metric>
    <metric>taxes01</metric>
    <metric>taxes02</metric>
    <metric>taxes03</metric>
    <metric>taxes04</metric>
    <metric>taxes05</metric>
    <metric>taxes06</metric>
    <metric>taxes07</metric>
    <metric>taxes08</metric>
    <metric>taxes09</metric>
    <metric>taxes10</metric>
    <metric>taxes11</metric>
    <metric>taxes12</metric>
    <metric>taxes13</metric>
    <metric>taxes14</metric>
    <metric>taxes15</metric>
    <metric>taxes16</metric>
    <metric>taxes17</metric>
    <metric>taxes18</metric>
    <metric>taxes19</metric>
    <metric>taxes20</metric>
    <metric>taxes21</metric>
    <metric>taxes22</metric>
    <metric>taxes23</metric>
    <metric>taxes24</metric>
    <metric>taxes25</metric>
    <metric>taxes26</metric>
    <metric>taxes27</metric>
    <metric>taxes28</metric>
    <metric>taxes29</metric>
    <metric>taxes30</metric>
    <metric>taxes31</metric>
    <metric>taxes32</metric>
    <metric>penalties01</metric>
    <metric>penalties02</metric>
    <metric>penalties03</metric>
    <metric>penalties04</metric>
    <metric>penalties05</metric>
    <metric>penalties06</metric>
    <metric>penalties07</metric>
    <metric>penalties08</metric>
    <metric>penalties09</metric>
    <metric>penalties10</metric>
    <metric>penalties11</metric>
    <metric>penalties12</metric>
    <metric>penalties13</metric>
    <metric>penalties14</metric>
    <metric>penalties15</metric>
    <metric>penalties16</metric>
    <metric>penalties17</metric>
    <metric>penalties18</metric>
    <metric>penalties19</metric>
    <metric>penalties20</metric>
    <metric>penalties21</metric>
    <metric>penalties22</metric>
    <metric>penalties23</metric>
    <metric>penalties24</metric>
    <metric>penalties25</metric>
    <metric>penalties26</metric>
    <metric>penalties27</metric>
    <metric>penalties28</metric>
    <metric>penalties29</metric>
    <metric>penalties30</metric>
    <metric>penalties31</metric>
    <metric>penalties32</metric>
    <metric>pctinformalemp01</metric>
    <metric>pctinformalemp02</metric>
    <metric>pctinformalemp03</metric>
    <metric>pctinformalemp04</metric>
    <metric>pctinformalemp05</metric>
    <metric>pctinformalemp06</metric>
    <metric>pctinformalemp07</metric>
    <metric>pctinformalemp08</metric>
    <metric>pctinformalemp09</metric>
    <metric>pctinformalemp10</metric>
    <metric>pctinformalemp11</metric>
    <metric>pctinformalemp12</metric>
    <metric>pctinformalemp13</metric>
    <metric>pctinformalemp14</metric>
    <metric>pctinformalemp15</metric>
    <metric>pctinformalemp16</metric>
    <metric>pctinformalemp17</metric>
    <metric>pctinformalemp18</metric>
    <metric>pctinformalemp19</metric>
    <metric>pctinformalemp20</metric>
    <metric>pctinformalemp21</metric>
    <metric>pctinformalemp22</metric>
    <metric>pctinformalemp23</metric>
    <metric>pctinformalemp24</metric>
    <metric>pctinformalemp25</metric>
    <metric>pctinformalemp26</metric>
    <metric>pctinformalemp27</metric>
    <metric>pctinformalemp28</metric>
    <metric>pctinformalemp29</metric>
    <metric>pctinformalemp30</metric>
    <metric>pctinformalemp31</metric>
    <metric>pctinformalemp32</metric>
    <metric>compliant01</metric>
    <metric>compliant02</metric>
    <metric>compliant03</metric>
    <metric>compliant04</metric>
    <metric>compliant05</metric>
    <metric>compliant06</metric>
    <metric>compliant07</metric>
    <metric>compliant08</metric>
    <metric>compliant09</metric>
    <metric>compliant10</metric>
    <metric>compliant11</metric>
    <metric>compliant12</metric>
    <metric>compliant13</metric>
    <metric>compliant14</metric>
    <metric>compliant15</metric>
    <metric>compliant16</metric>
    <metric>compliant17</metric>
    <metric>compliant18</metric>
    <metric>compliant19</metric>
    <metric>compliant20</metric>
    <metric>compliant21</metric>
    <metric>compliant22</metric>
    <metric>compliant23</metric>
    <metric>compliant24</metric>
    <metric>compliant25</metric>
    <metric>compliant26</metric>
    <metric>compliant27</metric>
    <metric>compliant28</metric>
    <metric>compliant29</metric>
    <metric>compliant30</metric>
    <metric>compliant31</metric>
    <metric>compliant32</metric>
    <enumeratedValueSet variable="Δθ">
      <value value="-0.8"/>
      <value value="-0.6"/>
      <value value="-0.5"/>
      <value value="-0.4"/>
      <value value="-0.3"/>
      <value value="-0.2"/>
      <value value="-0.1"/>
      <value value="0"/>
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.3"/>
      <value value="0.4"/>
      <value value="0.5"/>
      <value value="0.6"/>
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ΔPI">
      <value value="-15"/>
      <value value="-10"/>
      <value value="-7"/>
      <value value="-5"/>
      <value value="-4"/>
      <value value="-3"/>
      <value value="-2"/>
      <value value="-1"/>
      <value value="0"/>
      <value value="1"/>
      <value value="2"/>
      <value value="3"/>
      <value value="4"/>
      <value value="5"/>
      <value value="7"/>
      <value value="10"/>
      <value value="15"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
