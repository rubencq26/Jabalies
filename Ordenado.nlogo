; SLIDERS 
; prob_rep_jabalies
; njabaliesinicial
; prob_littering
; min_dias_construccion
; min_dias_derrumbe
; prob_contenedores_inteligentes
; nadversos
; nneutrales
; nalimentadores


globals [dias]

; -------------------------------------------------------------------------------------------------
;                  RAZAS
; -------------------------------------------------------------------------------------------------
breed [jabalies jabali]
breed [personas persona]
breed [comidas comida]

patches-own [polucion ticks_since_jabali ticks_since_human]
jabalies-own [energia felicidad velocidad xcomida ycomida nhuida]
personas-own [satisfaccion tipo velocidad destino] ; ( satisfaccion: [0, 100] )  ( tipo: "adverso" || "neutral" || "alimentador" )



; -------------------------------------------------------------------------------------------------
;                  SETUP
; -------------------------------------------------------------------------------------------------
to setup
  ca
  reset-ticks
  set dias 0

  ; TERRENO -------------------------------------
  ask patches [set polucion 0 set pcolor green]
  ask patches with [pxcor > 0] [set pcolor grey]


  ; CONTENEDORES --------------------------------
  ask patches with [pcolor = grey and (pxcor mod 8 = 0) and (pycor mod 8 = 0)] [
    ifelse (random 100 < 30) ; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
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
end



; -------------------------------------------------------------------------------------------------
;                  FUNCIONES DE SETUP
; -------------------------------------------------------------------------------------------------

; Jabalies --------------------------------------
to generar_jabalies
  create-jabalies njabaliesinicial [
    setxy [pxcor] of one-of patches with [pcolor = green ] [pycor ] of one-of patches with [pcolor = green]
    set color 33
    set shape "cow"
    set velocidad 0.1
    set felicidad random 100
    set energia random 100
    set xcomida -1
    set ycomida -1
    set nhuida 0
  ]
end

; Personas --------------------------------------
to generar_personas
  ; nadversos, nneutrales y nalimentadores son sliders [0, 100]
   create-personas 5 [ ; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    set tipo "adverso"
    set color red
  ]
  create-personas 5 [ ; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    set tipo "neutral"
    set color white
  ]
  create-personas 5 [ ; !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    set tipo "alimentador"
    set color pink
  ]
  ask personas [
    set satisfaccion (random 10) + 45
    set shape "person"
    setxy [pxcor] of one-of patches with [pcolor = gray] [pycor] of one-of patches with [pcolor = gray]
    set velocidad 0.1
    set destino one-of patches with [ pcolor = gray ]
  ]
end



; -------------------------------------------------------------------------------------------------
;                  GO
; -------------------------------------------------------------------------------------------------

to go

  while [count jabalies > 0] [

    ; DINAMICA DE JABALIES ----------------------
    ask jabalies [
      percibirjabali
      moverjabali
    ]
    ask n-of 5 jabalies [
      reproducirjabali
    ]


    ; DINAMICA DE PERSONAS ----------------------
    ask personas [
      mover_personas
      let salvajes jabalies in-cone 5 60
      if tipo = "adverso" and any? salvajes [cazar (one-of salvajes)]
      if tipo = "alimentador" and any? salvajes [alimentar (one-of salvajes)]
    ]


    ; DINAMICA DE CONTENEDORES ------------------
    if (ticks mod 24 = 0) [vaciar_contenedores] ; si 00:00, vaciar contenedores
    llena_contenedor ;se generan residuos


    ; DINAMICA DE PASTO -------------------------
    genera_pasto


    ; ACTUALIZACION FRONTERIZA ------------------
    ask patches [
      set ticks_since_jabali ticks_since_jabali + 1 
      set ticks_since_human ticks_since_human + 1
    ]
    ask patches with [(ticks_since_jabali / 24) > min_dias_construccion and pcolor = green] [
      if (count neighbors4 with [pcolor != green] > 0) and count comidas-here = 0 ; si lindo con la ciudad
        [ set pcolor grey ]
    ]
    ask patches with [(ticks_since_human / 24) > min_dias_derrumbe and pcolor != green] [ 
      if (count neighbors4 with [pcolor = green] > 0) and count comidas-here = 0  ; si lindo con el campo
        [ set pcolor green ]
    ]


    tick

  ] ; FIN DEL WHILE ==> LOS JABALIES SE EXTINGUIERON
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
        sprout 1 [
          set breed comidas
          set color green - 2
          set shape "plant"
        ]
      ]
    ]
  ]
end


; PERSONAS --------------------------------------
to mover_personas
  if patch-here = destino [ set destino one-of patches with [ pcolor = gray ]]
  face destino
  repeat 10 [ wiggle(0.1) ]
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
end

to alimentar [mascotita]
  while [distance mascotita > 0.2] [
    face mascotita
    repeat 10 [wiggle 0.01]
    ask patch-here [set ticks_since_human 0]
  ]
  ask mascotita [
    set felicidad felicidad + (random 100)
    if felicidad > 100 [ set felicidad 100 ]
  ]
end


; JABALIES --------------------------------------
to percibirjabali ; actualiza la direc y veloc segun el entorno
  ask jabalies [

    ; Escanear peligros
    let peligros personas in-cone 5 60 with [tipo = "adversos"]
    if nhuida > 0 [
      huir
      set nhuida (nhuida - 1)
    ]
    if any? peligros [
      set nhuida 10
      rt 180
      huir
    ]

    ; Escanear comida
    buscarcomida

    ; Escanear hacinamiento y soledad
    let vecinos jabalies in-radius 3
    if count vecinos > 7 [ ; si hay hacinamiento, huir
      rt 180
      set nhuida 5
      huir
    ]
    ifelse count vecinos > 0 
    [  ; si hay soledad, acercarse
        face min-one-of other jabalies [ distance myself ]
        set velocidad 0.1
    ]
    [  ; si no hay hacinamiento ni soledad, moverse normalmente
        set velocidad 0.1
    ]

  ]
end

to buscarcomida
  ifelse count comidas-on patch-here > 0 
  [ comer ]                                    ; si hay comida, comer
  [                                            ; si no hay comida, buscar comida
    let alimento one-of comidas in-cone 5 60
    if alimento != nobody [ face alimento ]
  ]
end

to huir
  rt 180
  repeat 10 [ set velocidad 0.025 ]
  set felicidad felicidad - 15
end

to comer
  let alimento count comidas-on patch-here
  ask comidas-on patch-here [die]
  set felicidad felicidad + (10 * alimento)
  if felicidad > 100 [ set felicidad 100 ]
end

to moverjabali
  set felicidad felicidad - 5
  ask patch-here [set ticks_since_jabali 0]
  if (ticks mod 24 > 20 or ticks mod 24 < 4) [
    repeat 10 [
      wiggle velocidad
    ]
  ]
end

to reproducirjabali
  let pareja count jabalies in-radius 2.5
  if pareja > 2 and pareja < 7[
    if random 100 < prob_rep_jabalies 
    [
      hatch 1 [
      set color 33
      set shape "cow"
      set velocidad 0.1
      set felicidad random 100
      set energia random 100
      set xcomida -1
      set ycomida -1
      set nhuida 0
      ]
    ]
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
