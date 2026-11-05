import{D as e,S as t,St as n,Tt as r,g as i,h as a,l as o,m as s,o as c,r as l,s as u,u as d,wt as f}from"./runtime-core.esm-bundler-B24rT8f3.js";import{ct as p,v as m}from"./index-CDtQfOJy.js";import{t as h}from"./baseinput-C8bwpXE7.js";import{t as g}from"./ProgressRing-DVjEryiW.js";var _=m.extend({name:`textarea`,style:`
    .p-textarea {
        font-family: inherit;
        font-feature-settings: inherit;
        font-size: 1rem;
        color: dt('textarea.color');
        background: dt('textarea.background');
        padding-block: dt('textarea.padding.y');
        padding-inline: dt('textarea.padding.x');
        border: 1px solid dt('textarea.border.color');
        transition:
            background dt('textarea.transition.duration'),
            color dt('textarea.transition.duration'),
            border-color dt('textarea.transition.duration'),
            outline-color dt('textarea.transition.duration'),
            box-shadow dt('textarea.transition.duration');
        appearance: none;
        border-radius: dt('textarea.border.radius');
        outline-color: transparent;
        box-shadow: dt('textarea.shadow');
    }

    .p-textarea:enabled:hover {
        border-color: dt('textarea.hover.border.color');
    }

    .p-textarea:enabled:focus {
        border-color: dt('textarea.focus.border.color');
        box-shadow: dt('textarea.focus.ring.shadow');
        outline: dt('textarea.focus.ring.width') dt('textarea.focus.ring.style') dt('textarea.focus.ring.color');
        outline-offset: dt('textarea.focus.ring.offset');
    }

    .p-textarea.p-invalid {
        border-color: dt('textarea.invalid.border.color');
    }

    .p-textarea.p-variant-filled {
        background: dt('textarea.filled.background');
    }

    .p-textarea.p-variant-filled:enabled:hover {
        background: dt('textarea.filled.hover.background');
    }

    .p-textarea.p-variant-filled:enabled:focus {
        background: dt('textarea.filled.focus.background');
    }

    .p-textarea:disabled {
        opacity: 1;
        background: dt('textarea.disabled.background');
        color: dt('textarea.disabled.color');
    }

    .p-textarea::placeholder {
        color: dt('textarea.placeholder.color');
    }

    .p-textarea.p-invalid::placeholder {
        color: dt('textarea.invalid.placeholder.color');
    }

    .p-textarea-fluid {
        width: 100%;
    }

    .p-textarea-resizable {
        overflow: hidden;
        resize: none;
    }

    .p-textarea-sm {
        font-size: dt('textarea.sm.font.size');
        padding-block: dt('textarea.sm.padding.y');
        padding-inline: dt('textarea.sm.padding.x');
    }

    .p-textarea-lg {
        font-size: dt('textarea.lg.font.size');
        padding-block: dt('textarea.lg.padding.y');
        padding-inline: dt('textarea.lg.padding.x');
    }
`,classes:{root:function(e){var t=e.instance,n=e.props;return[`p-textarea p-component`,{"p-filled":t.$filled,"p-textarea-resizable ":n.autoResize,"p-textarea-sm p-inputfield-sm":n.size===`small`,"p-textarea-lg p-inputfield-lg":n.size===`large`,"p-invalid":t.$invalid,"p-variant-filled":t.$variant===`filled`,"p-textarea-fluid":t.$fluid}]}}}),v={name:`BaseTextarea`,extends:h,props:{autoResize:Boolean},style:_,provide:function(){return{$pcTextarea:this,$parentInstance:this}}};function y(e){"@babel/helpers - typeof";return y=typeof Symbol==`function`&&typeof Symbol.iterator==`symbol`?function(e){return typeof e}:function(e){return e&&typeof Symbol==`function`&&e.constructor===Symbol&&e!==Symbol.prototype?`symbol`:typeof e},y(e)}function b(e,t,n){return(t=x(t))in e?Object.defineProperty(e,t,{value:n,enumerable:!0,configurable:!0,writable:!0}):e[t]=n,e}function x(e){var t=S(e,`string`);return y(t)==`symbol`?t:t+``}function S(e,t){if(y(e)!=`object`||!e)return e;var n=e[Symbol.toPrimitive];if(n!==void 0){var r=n.call(e,t);if(y(r)!=`object`)return r;throw TypeError(`@@toPrimitive must return a primitive value.`)}return(t===`string`?String:Number)(e)}var C={name:`Textarea`,extends:v,inheritAttrs:!1,observer:null,mounted:function(){var e=this;this.autoResize&&(this.observer=new ResizeObserver(function(){requestAnimationFrame(function(){e.resize()})}),this.observer.observe(this.$el))},updated:function(){this.autoResize&&this.resize()},beforeUnmount:function(){this.observer&&this.observer.disconnect()},methods:{resize:function(){if(this.$el.offsetParent){var e=this.$el.style.height,t=parseInt(e)||0,n=this.$el.scrollHeight;t&&n<t?(this.$el.style.height=`auto`,this.$el.style.height=`${this.$el.scrollHeight}px`):(!t||n>t)&&(this.$el.style.height=`${n}px`)}},onInput:function(e){this.autoResize&&this.resize(),this.writeValue(e.target.value,e)}},computed:{attrs:function(){return t(this.ptmi(`root`,{context:{filled:this.$filled,disabled:this.disabled}}),this.formField)},dataP:function(){return p(b({invalid:this.$invalid,fluid:this.$fluid,filled:this.$variant===`filled`},this.size,this.size))}}},w=[`value`,`name`,`disabled`,`aria-invalid`,`data-p`];function T(n,r,i,a,o,s){return e(),d(`textarea`,t({class:n.cx(`root`),value:n.d_value,name:n.name,disabled:n.disabled,"aria-invalid":n.invalid||void 0,"data-p":s.dataP,onInput:r[0]||=function(){return s.onInput&&s.onInput.apply(s,arguments)}},s.attrs),null,16,w)}C.render=T;var E={class:`flex p-1 bg-[#EEF1EF] rounded-xl`,role:`tablist`,"aria-label":`Modo de evaluación`},D=[`aria-selected`],O=[`aria-selected`],k=i({__name:`ModeTabs`,props:{activo:{}},emits:[`change`],setup(t,{emit:r}){let i=r;return(r,a)=>(e(),d(`div`,E,[u(`button`,{role:`tab`,"aria-selected":t.activo===`equipos`,onClick:a[0]||=e=>i(`change`,`equipos`),class:n([`h-9 px-4 rounded-[9px] text-[14px] transition-colors whitespace-nowrap`,t.activo===`equipos`?`bg-white text-[#0E7C59] font-semibold shadow-[0_1px_2px_rgba(22,32,27,0.12)]`:`text-[#5B6660] font-medium`])},`Por equipo`,10,D),u(`button`,{role:`tab`,"aria-selected":t.activo===`criterios`,onClick:a[1]||=e=>i(`change`,`criterios`),class:n([`h-9 px-4 rounded-[9px] text-[14px] transition-colors whitespace-nowrap`,t.activo===`criterios`?`bg-white text-[#0E7C59] font-semibold shadow-[0_1px_2px_rgba(22,32,27,0.12)]`:`text-[#5B6660] font-medium`])},`Por criterio`,10,O)]))}}),A={class:`flex-1 min-w-0 flex flex-col items-start gap-0.5`},j={class:`text-[14px] font-semibold text-[#16201B] truncate w-full`},M={class:`text-[12px] text-[#5B6660]`},N=i({__name:`TeamRow`,props:{equipo:{},progreso:{},active:{type:Boolean}},setup(t){let i=t,o=c(()=>i.progreso.total>0?Math.round(i.progreso.calificados/i.progreso.total*100):0);function s(e){return e.split(` `).filter(Boolean).slice(0,2).map(e=>(e[0]??``).toUpperCase()).join(``)}return(i,c)=>(e(),d(`button`,{class:n([`w-full flex items-center gap-2.5 min-h-[60px] px-2.5 rounded-xl border text-left transition-colors font-[inherit]`,t.active?`bg-[#E1F3EA] border-[#0E7C59]`:`bg-white border-transparent hover:bg-[#F4F6F4]`])},[u(`span`,{class:`w-9 h-9 rounded-[10px] flex items-center justify-center font-bold text-[13px] text-white flex-shrink-0`,style:f({background:t.equipo.color}),"aria-hidden":`true`},r(s(t.equipo.nombre)),5),u(`span`,A,[u(`span`,j,r(t.equipo.nombre),1),u(`span`,M,r(t.progreso.calificados)+`/`+r(t.progreso.total)+` criterios`,1)]),a(g,{percent:o.value,size:34,thickness:4},null,8,[`percent`])],2))}}),P={key:0,class:`w-6 h-6 rounded-lg bg-[#E1F3EA] text-[#0E7C59] flex items-center justify-center flex-shrink-0`,"aria-hidden":`true`},F={class:`flex-1 min-w-0 flex flex-col items-start gap-0.5`},I={class:`text-[14px] font-semibold text-[#16201B]`},L={class:`text-[12px] text-[#5B6660]`},R=i({__name:`CriterioRow`,props:{nombre:{},done:{},total:{},max:{},active:{type:Boolean},isLiderazgo:{type:Boolean}},setup(t){let i=t,a=c(()=>i.isLiderazgo?{text:`${i.done}/${i.total}`,cls:`bg-[#E1F3EA] text-[#0B6B4B]`}:i.done===i.total&&i.total>0?{text:`Completo`,cls:`bg-[#E1F3EA] text-[#0B6B4B]`}:i.done>0?{text:`En curso`,cls:`bg-[#FFF1D6] text-[#7A4F00]`}:{text:`Sin empezar`,cls:`bg-[#EEF0EE] text-[#4A544F]`});return(i,c)=>(e(),d(`button`,{class:n([`w-full flex items-center gap-2.5 min-h-[56px] px-3 rounded-xl border text-left transition-colors font-[inherit]`,[t.active?`bg-[#E1F3EA] border-[#0E7C59]`:`bg-white border-transparent hover:bg-[#F4F6F4]`,t.isLiderazgo?`border-[#A7F3D0] bg-gradient-to-r from-[#ECFDF5] to-white`:``]])},[t.isLiderazgo?(e(),d(`span`,P,[...c[0]||=[u(`svg`,{width:`13`,height:`13`,viewBox:`0 0 24 24`,fill:`none`,stroke:`currentColor`,"stroke-width":`2.5`,"aria-hidden":`true`},[u(`path`,{d:`M13 2L3 14h9l-1 8 10-12h-9l1-8z`})],-1)]])):o(``,!0),u(`span`,F,[u(`span`,I,r(t.nombre),1),u(`span`,L,[s(r(t.done)+`/`+r(t.total),1),t.max===void 0?o(``,!0):(e(),d(l,{key:0},[s(` · máx. `+r(t.max),1)],64))])]),u(`span`,{class:n([`text-[11px] font-semibold px-2 py-0.5 rounded-[6px] flex-shrink-0`,a.value.cls])},r(a.value.text),3)],2))}});export{C as i,N as n,k as r,R as t};