; SLIDERS
; prob_rep_jabalies
; njabaliesinicial
; prob_littering
; min_dias_construccion
; min_dias_derrumbe
; nadversos
; nneutrales
; nalimentadores
; numdepredadores
; horas_cultivo
; prob_contenedor_inteligente

; MONITORES
; dia
; hora

globals [jabaliesmuertos dias hora]

; -------------------------------------------------------------------------------------------------
;                  RAZAS
; -------------------------------------------------------------------------------------------------
breed [jabalies jabali]
breed [personas persona]
breed [comidas comida]
breed [depredadores depredador]

depredadores-own[velocidad objetivo destinod]
patches-own [polucion ticks_since_jabali ticks_since_human]
jabalies-own [velocidad nhuida nhijos]
personas-own [tipo velocidad destino] ; ( tipo: "adverso" || "neutral" || "alimentador" )



; -------------------------------------------------------------------------------------------------
;                  SETUP
; -------------------------------------------------------------------------------------------------
to setup
  ca
  reset-ticks
  set dias 0
  set hora 0

  ; TERRENO -------------------------------------
  ask patches [set polucion 0 set pcolor green]
  ask patches with [pxcor > 0] [set pcolor grey]


  ; CONTENEDORES --------------------------------
  ask patches with [pcolor = grey and (pxcor mod 8 = 0) and (pycor mod 8 = 0)] [
    ifelse (random 100 < prob_contenedor_inteligente)
    [ set pcolor yellow - 1 ] ; contenedores inteligentes
    [ set pcolor green - 2  ] ; contenedores normales
  ]

  ; PASTO --------------------------------------
  ask n-of 15 patches with [pcolor = green] [
    if count comidas-here = 0 [
      sprout 1 [
        set breed comidas
        set color green - 2
        set shape "plant"
      ]
    ]
    ask n-of 2 neighbors4 [
      if (pcolor = green and (count comidas-here = 0)) [
        sprout 1 [
          set breed comidas
          set color green - 2
          set shape "plant"
        ]
      ]
    ]
  ]

  ; AGENTES --------------------------------------
  generar_jabalies
  generar_personas
  generar_depredadores
end

; -------------------------------------------------------------------------------------------------
;                  FUNCIONES DE SETUP
; -------------------------------------------------------------------------------------------------

; Depredadores -----------------------------------
to generar_depredadores
  create-depredadores numdepredadores [
    setxy [pxcor] of one-of patches with [pcolor = green]
          [pycor] of one-of patches with [pcolor = green]
    set color red
    set shape "wolf"
    set velocidad 0.3
  ]
end

; Jabalies --------------------------------------
to generar_jabalies
  create-jabalies njabaliesinicial [
    setxy [pxcor] of one-of patches with [pcolor = green ] [pycor ] of one-of patches with [pcolor = green]
    set color 33
    set shape "cow"
    set velocidad 0.1
    set nhuida 0
    set nhijos 0
  ]
end

; Personas --------------------------------------
to generar_personas
  ; nadversos, nneutrales y nalimentadores son sliders [0, 100]
   create-personas nadversos [
    set tipo "adverso"
    set color red
  ]
  create-personas nneutrales [
    set tipo "neutral"
    set color white
  ]
  create-personas nalimentadores [
    set tipo "alimentador"
    set color pink
  ]
  ask personas [
    set shape "person"
    setxy [pxcor] of one-of patches with [pcolor = gray]
          [pycor] of one-of patches with [pcolor = gray]
    set velocidad 0.2
    set destino one-of patches with [ pcolor = gray ]
  ]
end



; -------------------------------------------------------------------------------------------------
;                  GO
; -------------------------------------------------------------------------------------------------
; boton go repeticion

to go

  if count jabalies <= 0 [ stop ]
  set hora ticks mod 24
  set dias (ticks / 24)
  set dias floor dias

  ; DINAMICA DE JABALIES ----------------------
  ask jabalies [
    percibirjabali
    moverjabali
  ]
  if (ticks mod 24 = 0) [
    ask jabalies [ reproducirjabali ]
  ] ; se reproducen por la noche

  ; DINAMICA DE DEPREDADORES ------------------
    ask depredadores[
    percibirdepredador
    moverdepredador
  ]

  ; DINAMICA DE PERSONAS ----------------------
  ask personas [
    mover_personas
    let salvajes jabalies in-radius 3
    if tipo = "adverso" and any? salvajes [cazar (one-of salvajes)]
  ]


  ; DINAMICA DE CONTENEDORES ------------------
  if (ticks mod 24 = 0) [vaciar_contenedores] ; si 00:00, vaciar contenedores
  llena_contenedor ;se generan residuos


  ; DINAMICA DE PASTO -------------------------
  if (ticks mod horas_cultivo = 0) [genera_pasto] ; horas_cultivo es un SLIDER


  ; ACTUALIZACION FRONTERIZA ------------------
  ask patches [
    set ticks_since_jabali ticks_since_jabali + 1
    set ticks_since_human ticks_since_human + 1
  ]
  ask patches with [(ticks_since_jabali / 24) > min_dias_construccion and pcolor = green and ticks_since_jabali > ticks_since_human] [
    if (count neighbors4 with [pcolor != green] > 0) ; si lindo con la ciudad
    [
      ask comidas-here [die]
      set pcolor grey
      if (pxcor mod 8 = 0) and (pycor mod 8 = 0) [
        ifelse (random 100 < prob_contenedor_inteligente)
        [ set pcolor yellow - 1 ]
        [ set pcolor green - 2  ]
      ]
    ]
  ]
  ask patches with [(ticks_since_human / 24) > min_dias_derrumbe and pcolor != green and ticks_since_human > ticks_since_jabali] [
    if (count neighbors4 with [pcolor = green] > 0)  ; si lindo con el campo
      [
        set pcolor green
        ask comidas-here [die]
      ]
  ]

  tick

end



; -------------------------------------------------------------------------------------------------
;                  FUNCIONES DE GO
; -------------------------------------------------------------------------------------------------


; CONTENEDORES ----------------------------------
to vaciar_contenedores
  ask comidas with [color = brown] [ die ]
end

to llena_contenedor
  if count patches with [pcolor = green - 2 and (count comidas-here) = 0] > 0 [
    ask one-of patches with [pcolor = green - 2 and (count comidas-here) = 0] [
      sprout 1 [
        set breed comidas
        set color brown
        set shape "box"
      ]
    ]
  ]
end


; PASTO -----------------------------------------
to genera_pasto
  if (count patches with [pcolor = green and (count comidas in-radius 4) = 0] > 0) [
    ; seleccionar una parcela en la que colocar pasto
    let nuevopasto one-of patches with [pcolor = green and (count comidas in-radius 4) = 0]

    ; colocar pasto
    ask nuevopasto [
      sprout 1 [
        set breed comidas
        set color green - 2
        set shape "plant"
      ]
      ask n-of 2 neighbors4 [ ; generar pasto alrededor del pasto nuevo
      if (pcolor = green)[
        sprout 1 [
          set breed comidas
          set color green - 2
          set shape "plant"
        ]
      ]
      ]
    ]
  ]
end


; PERSONAS --------------------------------------
to mover_personas
  if patch-here = destino [
    ifelse (random 10) = 0
    [
      set destino one-of patches in-radius 2.5 with [ pcolor = green ]
      if (destino = nobody) [set destino one-of patches in-radius 2.5 with [ pcolor = gray ]]
    ]
    [
      set destino one-of patches in-radius 2.5 with [ pcolor = gray ]]
      if (destino = nobody) [set destino one-of patches in-radius 2.5 with [ pcolor = green ]]
  ]
  face destino
  wiggle 0.2
  ask patch-here [set ticks_since_human 0]
  if (random 100) < prob_littering [
    hatch 1 [
      set breed comidas
      set color brown
      set shape "box"
    ]
  ]
end

to cazar [caza]
  face caza
  while [distance caza > 2] [
    fd 0.15
    ask patch-here [set ticks_since_human 0]
  ]
  ask caza [die]
  set jabaliesmuertos jabaliesmuertos + 1

end


; JABALIES --------------------------------------
to percibirjabali ; actualiza la direc y veloc segun el entorno
  ask jabalies [

    ; Escanear peligros
    let peligros personas in-radius 5  with [tipo = "adverso"] ;ERROR CON LA S FINAL
    let cazadores depredadores in-radius 5
    if nhuida > 0 [
      huir
      set nhuida (nhuida - 1)
    ]
    ifelse any? peligros [
      set nhuida 10
      face one-of peligros
      rt 180
      huir
    ][
    ifelse any? cazadores[
      set nhuida 10
      face one-of cazadores
      rt 180
      huir
    ][




    ; Escanear hacinamiento y soledad

    let vecinos jabalies in-radius 3
    ifelse count vecinos > 7 [ ; si hay hacinamiento, huir
      face one-of vecinos
      rt 180
      set nhuida 5
      huir
    ][
    ifelse count vecinos > 1
    [  ; si hay soledad, acercarse
        face min-one-of other jabalies [ distance myself ]
        set velocidad 0.2
    ]
    [  ; si no hay hacinamiento ni soledad, moverse normalmente
        set velocidad 0.2
    ]
    ]
    buscarcomida
  ]
  ]
  ]

end

to buscarcomida
  if count comidas-on patch-here > 0 [ comer ]
    ; Buscar comida normal
    let alimento one-of comidas in-cone 5 60

    ; Buscar persona alimentadora
    let humano one-of personas in-cone 5 60 with [tipo = "alimentador"]

    if alimento != nobody [ face alimento ]
    if humano != nobody   [ face humano   ] ; prioriza humano
end

to huir
  set velocidad 0.25
  wiggle velocidad
end

to comer
  let alimento count comidas-on patch-here
  ask comidas-on patch-here [die]
end

to moverjabali
  if (ticks mod 24 > 20 or ticks mod 24 < 4) [
    wiggle velocidad
    ask patch-here [set ticks_since_jabali 0]
  ]
end

to reproducirjabali
  let pareja count jabalies in-radius 2.5
  let familia count jabalies in-radius 3
  if pareja > 2 and familia < 7[
    if(nhijos < 2)[
    if random 100 < prob_rep_jabalies
    [
      hatch 1 [
      set color 33
      set shape "cow"
      set velocidad 0.1
      set nhuida 0
      set nhijos 0
      ]
      set nhijos nhijos + 1
    ]
    ]
  ]
end

; DEPREDADORES -------------------------------------
to percibirdepredador
  set objetivo nobody
  ; Si no estoy en verde, doy la vuelta para volver al bosque
  if [pcolor] of patch-here != green [
    rt 180
    fd 1
  ]

  let presas jabalies in-cone 5 60

  ifelse any? presas [
    set objetivo min-one-of presas [distance myself]
    face objetivo
  ][
    ; CAMBIO AQUÍ: Buscar un parche verde solo en el radar cercano (radio de 5)
    let parche-cercano one-of patches in-radius 5 with [pcolor = green]
    if parche-cercano != nobody [
      face parche-cercano
    ]
  ]
end

to moverdepredador
  ifelse objetivo != nobody
  [
    ifelse distance objetivo > 1
      [ fd velocidad ]
      [
        ask objetivo [ die ]
        set jabaliesmuertos jabaliesmuertos + 1
        set objetivo nobody
      ]
  ]
  [
    ; CAMBIO: Movimiento errático constante para explorar
    rt random 40 - 20  ; Gira un poco a la izquierda o derecha cada tick
    fd velocidad

    ; Cada cierto tiempo corto, un giro brusco para cambiar de dirección
    if random 100 < 5 [ rt random 360 ]
  ]
end


; -------------------------------------------------------------------------------------------------
;                  FUNCIONES AUXILIARES
; -------------------------------------------------------------------------------------------------
to wiggle [distancia]
  rt random 1
  lt random 1
  fd distancia
end
@#$#@#$#@
GRAPHICS-WINDOW
513
10
1074
572
-1
-1
13.5
1
10
1
1
1
0
0
0
1
-20
20
-20
20
0
0
1
ticks
30.0

BUTTON
22
59
85
92
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

SLIDER
23
100
195
133
njabaliesinicial
njabaliesinicial
1
50
45.0
1
1
NIL
HORIZONTAL

BUTTON
131
59
194
92
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
1

SLIDER
23
201
195
234
nadversos
nadversos
0
100
15.0
1
1
NIL
HORIZONTAL

SLIDER
23
236
195
269
nalimentadores
nalimentadores
0
100
20.0
1
1
NIL
HORIZONTAL

SLIDER
23
270
195
303
nneutrales
nneutrales
0
100
20.0
1
1
NIL
HORIZONTAL

SLIDER
23
338
195
371
min_dias_construccion
min_dias_construccion
0
100
3.0
1
1
NIL
HORIZONTAL

SLIDER
23
372
195
405
min_dias_derrumbe
min_dias_derrumbe
0
100
3.0
1
1
NIL
HORIZONTAL

SLIDER
23
168
195
201
prob_rep_jabalies
prob_rep_jabalies
0
100
20.0
1
1
NIL
HORIZONTAL

SLIDER
23
304
195
337
prob_littering
prob_littering
0
100
5.0
1
1
NIL
HORIZONTAL

MONITOR
218
62
298
107
NIL
hora
17
1
11

PLOT
217
115
490
348
Jabalies
horas
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -7858858 true "" "plot count jabalies"
"pen-1" 1.0 0 -7500403 true "" "plot jabaliesmuertos"

SLIDER
24
453
196
486
numdepredadores
numdepredadores
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
25
494
197
527
horas_cultivo
horas_cultivo
0
100
70.0
1
1
NIL
HORIZONTAL

SLIDER
17
531
215
564
prob_contenedor_inteligente
prob_contenedor_inteligente
0
100
12.0
1
1
NIL
HORIZONTAL

PLOT
218
351
498
554
Evolución terreno
horas
N casillas
0.0
720.0
0.0
1600.0
true
false
"" ""
PENS
"default" 1.0 0 -11085214 true "" "ifelse(ticks > 1)[plot count patches with [pcolor = green]][plot 800]"
"pen-1" 1.0 0 -7500403 true "" "ifelse(ticks > 1)[plot count patches with [pcolor != green]][plot 800]"

MONITOR
309
63
390
108
dias
dias
0
1
11

@#$#@#$#@
## WHAT IS IT?

Una simulación en la que se modela el comportamiento de una población de jabalíes asentada al lado de un área urbana. 

Los jabalíes buscan comida, huyen de aquello que intente hacerles daño y se reproducen. Las personas, en cambio, se mueven con libertad prefiriendo el interior de los límites de la zona urbanizada. A lo largo del tiempo, la frontera entre la zona silvestre y lo que consideramos ciudad se modifica por los comportamientos de sendos jabalíes y personas.

## HOW IT WORKS

El mundo se divide en dos zonas:
Zona silvestre (verde). Es el hábitat de los jabalíes. Cueta con una fuente automática de comida: la vegetación, y además protege a los jabalíes del ataque de los humanos, que por lo general prefieren no salir de la ciudad. 

Zona urbanizada / ciudad (gris). Es el hábitat de las personas. Cuenta con espacios designados para contenedores (los cuadrados dentro de la ciudad) en los que los ciudadanos depositan periódicamente su basura. Algunos de estos contenedores (los amarillos) son especiales e impiden la entrada de jabalíes buscando alimento, el resto no lo evita y por tanto se pueden convertir en objetivos más fáciles de atacar que el pasto.

La frontera entre ambas zonas es dinámica. Cuando pasa un número determinado de días (MIN_DIAS_DERRUMBE) en los que ningún humano ha pisado una parcela de ciudad que colinde con la zona silvestre, esta pasa a ser zona silvestre, adquiriendo todas las características de la misma. En cambio, si pasa un número determinado de días (MIN_DIAS_CONSTRUCCION) en los que ningún jabalí ha pisado una parcela silvestre que colinde con la ciudad, los humanos conquistan el territorio y dicha parcela pasa a ser territorio urbano con todas sus características.


Sobre el terreno coexisten cuatro razas (breeds) de agente en el modelo:
Personas. Son los habitantes de la zona urbanizada, se mueven hacia un destino aleatorio -priorizando el terreno urbanizado- hasta llegar a él. Su actitud ante los jabalíes puede ser adversa, los matan al verlos; neutral, los ignoran; o amigable, alimentándolos como si fueran mascotas. La población total de personas en esta simulación es fija.

Jabalíes. Habitan predominantemente en la zona silvestre y están en continuo movimiento. Cada hora (tick) que pasa, escanean su entorno y actualizan su comportamiento acordemente: al detectar la presencia de una persona adversa o un depredador, se dirijen en dirección opuesta a él e incrementan su velocidad para huir; al detectar la de una persona amigable, dirigen su trayectoria a esta para ser alimentado; cuando en su vecindad coexisten más de 7 jabalíes, se siente abrumado y huye, cuando no hay ningún otro, dirige su trayectoria al jabalí más cercano. Cuando todo en su entorno está correcto, busca comida. Cada hora hay una posibilidad de que dos jabalíes que se encuentren cerca tengan una cría (cada jabalí puede tener un máximo de 2 crías por día). Los jabalíes sólo pueden morir si algo de su entorno les mata.

Depredadores. Habitan predominantemente en la zona silvestre, pudiendo incurrir en la ciudad cuando perciben a una presa pero volviendo rápidamente. Cada tick buscarán a una presa si es que no hubieran seleccionado ya a una. Se dirigen hacia ella y cuando la distancia es inferior o igual a 1, la matan. Cuando se quedan sin objetivo, deambulan (tendiendo a situarse en el centro geométrico de la zona silvestre). La población de deprededadores es estática a lo largo de la ejecución. 

Comida. Objetivo de los jabalíes. Se genera automáticamente en la zona silvestre por el crecimiento de pasto (esta comida es verde). En la ciudad, conforme pasan las horas se genera automáticamente en los lugares designados para contenedores ordinarios, que por falta de control permiten la entrada de jabalíes que buscan alimento. Además, las personas tienen una probabilidad de tirar sus propios desechos a la calle mientras caminan (esta basura es marrón).


## HOW TO USE IT

Mediante los diferentes sliders se pueden modificar todos los parámetros del modelo. Diferentes configuraciones iniciales derivan en diferente comportamiento por parte de personas y jabalíes. Una vez que todo esté configurado, presione el botón de setup que creará un mundo nuevo y lo poblará acorde a la configuración; después, presiona go para iniciar el reloj.

# GUÍA DE CONFIGURACIÓN:
tasa_reproduccion_jabalies: Establece la probabilidad de que cada jabalí se reproduzca en un día. Los jabalíes se reproducen a las 00.00 y que lo hagan o no queda determinado por un número aleatorio de 0 a 99, cuando dicho número sea inferior al valor de tasa_reproduccion_jabalies, esa tortuga se reproducirá, dando lugar a un nuevo individuo.

poblacion_jabalies_inicial: Establece la cantidad de jabalíes que se generan en el setup dentro de la zona silvestre.

probabilidad_arrojar_basura: Establece la probabilidad de que cada ciudadano arroje desechos orgánicos por la calle mientras camina. Cada vez que da un paso, se genera un número aleatorio de 0 a 99, cuando dicho número sea inferior al valor de probabilidad_arrojar_basura, esa persona generará una comida en su parcela actual.

dias_para_urbanizar: Cuando pasan dias_para_urbanizar días (cada día son 24 ticks) sin que un jabalí acceda a una parcela fronteriza de la zona silvestre, esta pasará a ser susceptible de urbanizarse (convertirse en ciudad).

dias_para_desurbanizar: Cuando pasan dias_para_desurbanizar días (cada día son 24 ticks) sin que una persona acceda a una parcela fronteriza de zona urbana, esta pasará a ser susceptible de desurbanizarse (convertirse en zona silvestre).

proporcion_contenedoresAA: Establece la probabilidad de que cada contenedor generado sea iniciado como contenedor inteligente. En la creación de contenedores, se genera un número aleatorio de 0 a 99, cuando dicho número es inferior a proporcion_contenedoresAA, el contenedor es inteligente. 

poblacion_adversa: Establece la cantidad de habitantes de la ciudad con una actitud adversa hacia los jabalíes.

poblacion_neutral: Establece la cantidad de habitantes de la ciudad con una actitud neutral hacia los jabalíes.

poblacion_alimentadora: Establece la cantidad de habitantes de la ciudad con una actitud amigable hacia los jabalíes.

poblacion_depredadores_inicial: Establece la cantidad de depredadores en la simulación.

horas_cultivo: Establece la cantidad de ticks que pasan desde que se generan parcelas de comida en la zona silvestre hasta que se vuelven a generar.




## THINGS TO NOTICE

En muchos casos, la presencia de jabalíes en territorio urbano es casi inevitable. La reproducción de jabalíes puede descontrolarse con facilidad alterando los valores de población de depredadores o reduciendo demasiado la cantidad de ciudadanos adversos. Para que los jabalíes invadan la ciudad, es notablemente relevante la tendencia de los ciudadanos a tirar basura, más incluso que la proporción de contenedores inteligentes.
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
NetLogo 6.3.0
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
