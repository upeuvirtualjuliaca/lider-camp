import{B as e,D as t,S as n,St as r,Tt as i,Z as a,c as o,g as s,h as c,k as l,m as u,o as d,p as f,r as p,rt as m,s as h,u as g,w as _}from"./runtime-core.esm-bundler-B24rT8f3.js";import{g as v,p as y}from"./index-NuamwWxX.js";import{t as b}from"./_plugin-vue_export-helper-BDNMzG2s.js";import{t as x}from"./message-DAq8s9tP.js";import{o as S}from"./criterios.service-Cm5WwfVH.js";var C=v.extend({name:`progressspinner`,style:`
    .p-progressspinner {
        position: relative;
        margin: 0 auto;
        width: 100px;
        height: 100px;
        display: inline-block;
    }

    .p-progressspinner::before {
        content: '';
        display: block;
        padding-top: 100%;
    }

    .p-progressspinner-spin {
        height: 100%;
        transform-origin: center center;
        width: 100%;
        position: absolute;
        top: 0;
        bottom: 0;
        left: 0;
        right: 0;
        margin: auto;
        animation: p-progressspinner-rotate 2s linear infinite;
    }

    .p-progressspinner-circle {
        stroke-dasharray: 89, 200;
        stroke-dashoffset: 0;
        stroke: dt('progressspinner.colorOne');
        animation:
            p-progressspinner-dash 1.5s ease-in-out infinite,
            p-progressspinner-color 6s ease-in-out infinite;
        stroke-linecap: round;
    }

    @keyframes p-progressspinner-rotate {
        100% {
            transform: rotate(360deg);
        }
    }
    @keyframes p-progressspinner-dash {
        0% {
            stroke-dasharray: 1, 200;
            stroke-dashoffset: 0;
        }
        50% {
            stroke-dasharray: 89, 200;
            stroke-dashoffset: -35px;
        }
        100% {
            stroke-dasharray: 89, 200;
            stroke-dashoffset: -124px;
        }
    }
    @keyframes p-progressspinner-color {
        100%,
        0% {
            stroke: dt('progressspinner.color.one');
        }
        40% {
            stroke: dt('progressspinner.color.two');
        }
        66% {
            stroke: dt('progressspinner.color.three');
        }
        80%,
        90% {
            stroke: dt('progressspinner.color.four');
        }
    }
`,classes:{root:`p-progressspinner`,spin:`p-progressspinner-spin`,circle:`p-progressspinner-circle`}}),w={name:`ProgressSpinner`,extends:{name:`BaseProgressSpinner`,extends:y,props:{strokeWidth:{type:String,default:`2`},fill:{type:String,default:`none`},animationDuration:{type:String,default:`2s`}},style:C,provide:function(){return{$pcProgressSpinner:this,$parentInstance:this}}},inheritAttrs:!1,computed:{svgStyle:function(){return{"animation-duration":this.animationDuration}}}},T=[`fill`,`stroke-width`];function E(e,r,i,a,o,s){return t(),g(`div`,n({class:e.cx(`root`),role:`progressbar`},e.ptmi(`root`)),[(t(),g(`svg`,n({class:e.cx(`spin`),viewBox:`25 25 50 50`,style:s.svgStyle},e.ptm(`spin`)),[h(`circle`,n({class:e.cx(`circle`),cx:`50`,cy:`50`,r:`20`,fill:e.fill,"stroke-width":e.strokeWidth,strokeMiterlimit:`10`},e.ptm(`circle`)),null,16,T)],16))],16)}w.render=E;var D={class:`calendario-view`},O={key:0,class:`calendario-view__cargando`},k={key:2,class:`calendario-wrap`},A={class:`calendario-tabla`},j={class:`cal-fila-cat`},M={colspan:6,class:`cal-td-cat`},N={class:`cal-td cal-td--nombre`},P={class:`cal-codigo`},F={key:0,class:`cal-icono cal-icono--ok`},I={key:1,class:`cal-icono cal-icono--cancel`},L={key:2,class:`cal-icono cal-icono--na`},R=`UNICO`,z=b(s({__name:`CalendarioView`,setup(n){let s=a([]),v=a(!0),y=a(``),b=[`J`,`V`,`S`,`D`],C={J:`Jue`,V:`Vie`,S:`Sáb`,D:`Dom`},T={inscripcion:`Inscripción`,armado:`Armado de campamento`,orden_cocina:`Orden y cocina`,ceremonias_participacion:`Ceremonias y participación`,liderazgo:`Liderazgo`},E=[`inscripcion`,`armado`,`orden_cocina`,`ceremonias_participacion`,`liderazgo`];_(async()=>{try{s.value=await S.getCalendario()}catch(e){y.value=e instanceof Error?e.message:`Error al cargar el calendario`}finally{v.value=!1}});let z=d(()=>{let e=new Set,t=[];for(let n of s.value)e.has(n.codigo)||(e.add(n.codigo),t.push(n));return t}),B=d(()=>{let e=z.value.reduce((e,t)=>(e[t.categoria]||(e[t.categoria]=[]),e[t.categoria].push(t),e),{});return E.filter(t=>e[t]?.length).map(t=>({categoria:t,items:e[t]??[]}))});function V(e,t){let n=s.value.find(n=>n.codigo===e&&n.momento===t);return n?n.estado:null}function H(e){return s.value.some(t=>t.codigo===e&&t.momento===R)}return(n,a)=>(t(),g(`div`,D,[a[6]||=h(`h1`,{class:`calendario-view__titulo`},`Calendario de evaluación`,-1),a[7]||=h(`p`,{class:`calendario-view__desc`},` Días en que se evalúa cada criterio durante el campamento. `,-1),v.value?(t(),g(`div`,O,[c(m(w),{style:{width:`2rem`,height:`2rem`}})])):y.value?(t(),o(m(x),{key:1,severity:`error`,closable:!1},{default:e(()=>[u(i(y.value),1)]),_:1})):(t(),g(`div`,k,[h(`table`,A,[h(`thead`,null,[h(`tr`,null,[a[0]||=h(`th`,{class:`cal-th cal-th--nombre`},`Criterio`,-1),(t(),g(p,null,l(b,e=>h(`th`,{key:e,class:`cal-th cal-th--dia`},i(C[e]),1)),64)),a[1]||=h(`th`,{class:`cal-th cal-th--dia`},`Único`,-1)])]),h(`tbody`,null,[(t(!0),g(p,null,l(B.value,e=>(t(),g(p,{key:e.categoria},[h(`tr`,j,[h(`td`,M,i(T[e.categoria]??e.categoria),1)]),(t(!0),g(p,null,l(e.items,e=>(t(),g(`tr`,{key:e.codigo,class:`cal-fila`},[h(`td`,N,[h(`span`,P,i(e.codigo),1),u(` `+i(e.nombre),1)]),H(e.codigo)?(t(),g(p,{key:0},[(t(),g(p,null,l(b,e=>h(`td`,{key:e,class:`cal-td cal-td--celda cal-td--na`},[...a[2]||=[h(`span`,{class:`cal-icono cal-icono--na`},`—`,-1)]])),64)),a[3]||=h(`td`,{class:`cal-td cal-td--celda`},[h(`span`,{class:`cal-icono cal-icono--unico`},`Único`)],-1)],64)):(t(),g(p,{key:1},[(t(),g(p,null,l(b,n=>h(`td`,{key:n,class:r([`cal-td cal-td--celda`,{"cal-td--na":!V(e.codigo,n)}])},[V(e.codigo,n)===`programado`?(t(),g(`span`,F,`✓`)):V(e.codigo,n)===`cancelado`?(t(),g(`span`,I,`✗`)):(t(),g(`span`,L,`—`))],2)),64)),a[4]||=h(`td`,{class:`cal-td cal-td--celda cal-td--na`},[h(`span`,{class:`cal-icono cal-icono--na`},`—`)],-1)],64))]))),128))],64))),128))])]),a[5]||=f(`<div class="calendario-leyenda" data-v-9c3f58d1><span class="leyenda-item" data-v-9c3f58d1><span class="cal-icono cal-icono--ok" data-v-9c3f58d1>✓</span> Programado</span><span class="leyenda-item" data-v-9c3f58d1><span class="cal-icono cal-icono--na" data-v-9c3f58d1>—</span> No aplica</span><span class="leyenda-item" data-v-9c3f58d1><span class="cal-icono cal-icono--cancel" data-v-9c3f58d1>✗</span> Cancelado</span></div>`,1)]))]))}}),[[`__scopeId`,`data-v-9c3f58d1`]]);export{z as default};