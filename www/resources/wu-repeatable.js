// wu-base.js

var wu = wu || {};

wu.log = function(o) {
    if (window.console && o) {
        window.console.log(o);
    }
};

wu.setStyle = setStyle = function(el, property, val) {
    el.style[property] = val;
};

wu.applyStyles = function(el, styles){
    if(styles){
        if(typeof styles == "string"){
            var re = /\s?([a-z\-]*)\:\s?([^;]*);?/gi;
            var matches;
            while ((matches = re.exec(styles)) != null){
                wu.setStyle(el,matches[1], matches[2]);
            }
        }else if (typeof styles == "object"){
            for (var style in styles){
                wu.setStyle(el,style, styles[style]);
            }
        }else if (typeof styles == "function"){
            wu.applyStyles(el, styles.call());
        }
    }
}

function isArray(v){
    return v && typeof v.length == 'number' && typeof v.splice == 'function';
}
function createDom(o, parentNode){
    var el;
    if (isArray(o)) {                       // Allow Arrays of siblings to be inserted
        el = document.createDocumentFragment(); // in one shot using a DocumentFragment
        for(var i = 0, l = o.length; i < l; i++) 
        {
            createDom(o[i], el);
        }
    } else if (typeof o == "string") {         // Allow a string as a child spec.
        el = document.createTextNode(o);
    } else {
        el = document.createElement(o['tag']||'div');
        var useSet = !!el.setAttribute; // In IE some elements don't have setAttribute
        for(var attr in o){
            if(attr == "tag" || attr == "children" || attr == "cn" || attr == "html" || attr == "style" || typeof o[attr] == "function") continue;
            if(attr=="cls"){
                el.className = o["cls"];
            }else{
                if(useSet) el.setAttribute(attr, o[attr]);
                else el[attr] = o[attr];
            }
        }
        wu.applyStyles(el, o['style']);
        var cn = o['children'] || o['cn'];
        if(cn){
            createDom(cn, el);
        } else if(o['html']){
            el.innerHTML = o['html'];
        }
    }
    if(parentNode){
        parentNode.appendChild(el);
    }
    return el;
};

// Mozilla 1.8 has support for indexOf, lastIndexOf, forEach, filter, map, some, every
// http://developer-test.mozilla.org/docs/Core_JavaScript_1.5_Reference:Objects:Array:lastIndexOf
if (!Array.prototype.indexOf) {
    Array.prototype.indexOf = function (obj, fromIndex) {
        if (fromIndex == null) {
            fromIndex = 0;
        } else if (fromIndex < 0) {
            fromIndex = Math.max(0, this.length + fromIndex);
        }
        for (var i = fromIndex; i < this.length; i++) {
            if (this[i] === obj)
                return i;
        }
        return -1;
    };
}

String.prototype.trim = function() {
    return this.replace(/^\s+|\s+$/g,"");
}

// wu-repeatable.js

wu.repeatable = {
    counter:0
};

wu.repeatable.addChoice = function(e) {

    wu.log(e);
    wu.repeatable.counter++;

    // TODO: get the spec attribute, generate name, and create dom
    // render_input ensures that SPEC["text"] is included 
    // (via a call to ::xo::formfield::text->require_spec or some such)
    // Example of spec attribute:
    // {'tag':'input','cls':'wu-repeatable-choice','type':'text','name':'some_id:'};
    var json = e.getAttribute('spec'); 
    var spec = eval("(" + json + ')');

    // use negative count for ids to avoid conflicts with
    // code generated on the server-side
    spec['id'] = spec['name'] + ':-' + wu.repeatable.counter;

    var d = document;
    var el = e.parentNode;
    var newNode=createDom({'tag':'div',
			   'children':[{'tag':'div','cls':'wu-repeatable-arrows',
					'children':[{'tag':'a','cls':'wu-repeatable-action','href':'#','onclick':'return wu.repeatable.moveUp(this)','html':''}]},
				       spec,
				       {'tag':'a','cls':'fl','href':'#','onclick':'return wu.repeatable.delChoice(this)','html':'[x]'}
				      ]});

    el.insertBefore(newNode,e);
    return false;
};

wu.repeatable.delChoice = function(e) {
    var el = e.parentNode.parentNode;
    el.removeChild(e.parentNode);
    wu.repeatable.update();
    return false;
};

wu.repeatable.update = function() {}