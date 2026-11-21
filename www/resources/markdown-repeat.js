(() => {
    "use strict";

    const editor = window.openacsMarkdown;
    if (!editor) {
        return;
    }

    const fields = "textarea[data-repeat-template-id]";
    document.addEventListener("xowiki:repeat-before-delete", event => {
        for (const field of event.target.querySelectorAll(fields)) {
            if (!editor.restore(field)) {
                event.preventDefault();
                return;
            }
        }
    });

    document.addEventListener("xowiki:repeat-update", event => {
        for (const field of event.target.querySelectorAll(fields)) {
            editor.mountCopy(field, field.dataset.repeatTemplateId);
        }
    });
})();
