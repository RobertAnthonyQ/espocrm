define('custom:views/fields/pdf-embed', ['views/fields/file'], function (FileFieldView) {
    return class extends FileFieldView {
        getValueForDisplay() {
            const fallback = super.getValueForDisplay();

            if (!this.isDetailMode()) {
                return fallback;
            }

            const id = this.model.get(this.idName);
            const name = this.model.get(this.nameName);
            const type = this.model.get(this.typeName);

            const isPdf = type === 'application/pdf' || /\.pdf$/i.test(name || '');

            if (!id || !isPdf) {
                return fallback;
            }

            const url = this.getDownloadUrl(id);
            const wrapper = document.createElement('section');
            wrapper.className = 'acme-pdf-preview';
            wrapper.setAttribute('aria-label', `Vista previa de ${name}`);

            const toolbar = document.createElement('div');
            toolbar.className = 'acme-pdf-preview__toolbar';

            const title = document.createElement('span');
            title.className = 'acme-pdf-preview__title';
            title.textContent = name;

            const open = document.createElement('a');
            open.className = 'btn btn-default btn-sm';
            open.href = url;
            open.target = '_blank';
            open.rel = 'noopener';
            open.innerHTML = '<span class="fas fa-external-link-alt" aria-hidden="true"></span> Abrir PDF';

            toolbar.append(title, open);

            const frame = document.createElement('iframe');
            frame.className = 'acme-pdf-preview__frame';
            frame.src = `${url}#toolbar=1&navpanes=0&view=FitH`;
            frame.title = `Vista previa de ${name}`;
            frame.loading = 'lazy';

            wrapper.append(toolbar, frame);

            return wrapper.outerHTML;
        }

        afterRender() {
            super.afterRender();

            if (document.getElementById('acme-pdf-preview-style')) {
                return;
            }

            const style = document.createElement('style');
            style.id = 'acme-pdf-preview-style';
            style.textContent = `
                .acme-pdf-preview {
                    overflow: hidden;
                    background: var(--panel-bg);
                    border: var(--1px) solid var(--panel-default-border);
                    border-radius: var(--panel-border-radius);
                }
                .acme-pdf-preview__toolbar {
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    gap: var(--12px);
                    min-height: var(--46px);
                    padding: var(--7px) var(--10px);
                    background: var(--main-gray);
                    border-bottom: var(--1px) solid var(--panel-default-border);
                }
                .acme-pdf-preview__title {
                    min-width: 0;
                    overflow: hidden;
                    color: var(--text-color);
                    font-weight: 600;
                    text-overflow: ellipsis;
                    white-space: nowrap;
                }
                .acme-pdf-preview__frame {
                    display: block;
                    width: 100%;
                    height: min(68vh, 680px);
                    min-height: 460px;
                    border: 0;
                    background: var(--body-bg);
                }
                @media (max-width: 767px) {
                    .acme-pdf-preview__frame {
                        height: 60vh;
                        min-height: 360px;
                    }
                }
                @media (prefers-reduced-motion: reduce) {
                    .acme-pdf-preview *,
                    .acme-pdf-preview *::before,
                    .acme-pdf-preview *::after {
                        scroll-behavior: auto !important;
                        transition-duration: 0.01ms !important;
                    }
                }
            `;
            document.head.append(style);
        }
    };
});
