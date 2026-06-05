'use strict';

// ── Swift messaging ──

function sendToSwift(msg) {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.glass) {
        window.webkit.messageHandlers.glass.postMessage(msg);
    }
}

// ── Active popover tracking ──

let activePopover = null;

function dismissActivePopover(commit) {
    if (!activePopover) return;
    if (commit) activePopover.commit();
    activePopover.el.remove();
    activePopover = null;
}

document.addEventListener('mousedown', (e) => {
    if (activePopover && !activePopover.el.contains(e.target)) {
        dismissActivePopover(true);
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && activePopover) {
        dismissActivePopover(false);
        e.preventDefault();
    }
});

// ── SmartSlider ──

class SmartSlider {
    constructor(containerId, opts) {
        this.id = opts.id;
        this.min = opts.min;
        this.max = opts.max;
        this.step = opts.step;
        this.value = opts.value;
        this.onChange = opts.onChange;
        this.decimals = opts.step < 1 ? Math.max(0, -Math.floor(Math.log10(opts.step))) : 0;

        const container = document.getElementById(containerId);
        if (!container) return;
        this.render(container);
    }

    render(container) {
        const label = document.createElement('div');
        label.className = 'ui-label';
        label.textContent = this.id.replace(/([A-Z])/g, ' $1').toUpperCase().trim();

        const row = document.createElement('div');
        row.className = 'slider-row';

        this.input = document.createElement('input');
        this.input.type = 'range';
        this.input.min = this.min;
        this.input.max = this.max;
        this.input.step = this.step;
        this.input.value = this.value;

        this.valueSpan = document.createElement('span');
        this.valueSpan.className = 'ui-value';
        this.valueSpan.textContent = this.formatValue(this.value);

        this.input.addEventListener('input', () => {
            this.value = parseFloat(this.input.value);
            this.valueSpan.textContent = this.formatValue(this.value);
            if (this.onChange) this.onChange(this.value);
        });

        this.valueSpan.addEventListener('dblclick', (e) => {
            e.preventDefault();
            this.showPopover();
        });

        row.appendChild(this.input);
        row.appendChild(this.valueSpan);
        container.appendChild(label);
        container.appendChild(row);
    }

    formatValue(v) {
        return this.decimals > 0 ? v.toFixed(this.decimals) : Math.round(v).toString();
    }

    setValue(v) {
        this.value = Math.max(this.min, Math.min(this.max, v));
        this.input.value = this.value;
        this.valueSpan.textContent = this.formatValue(this.value);
        if (this.onChange) this.onChange(this.value);
    }

    updateRange(newMin, newMax) {
        this.min = newMin;
        this.max = newMax;
        this.input.min = newMin;
        this.input.max = newMax;
        this.value = Math.max(newMin, Math.min(newMax, this.value));
        this.input.value = this.value;
        this.valueSpan.textContent = this.formatValue(this.value);
    }

    showPopover() {
        dismissActivePopover(true);

        const rect = this.valueSpan.getBoundingClientRect();
        const popover = document.createElement('div');
        popover.className = 'edit-popover';

        const fields = [
            { label: 'MIN', value: this.min },
            { label: 'VAL', value: this.value },
            { label: 'MAX', value: this.max }
        ];

        const inputs = [];

        fields.forEach((f) => {
            const field = document.createElement('div');
            field.className = 'edit-field';

            const lbl = document.createElement('div');
            lbl.className = 'edit-label';
            lbl.textContent = f.label;

            const inp = document.createElement('input');
            inp.type = 'text';
            inp.value = this.decimals > 0 ? f.value.toFixed(this.decimals) : f.value;

            inp.addEventListener('keydown', (e) => {
                if (e.key === 'Enter') {
                    dismissActivePopover(true);
                    e.preventDefault();
                } else if (e.key === 'Tab') {
                    if (!e.shiftKey && inputs.indexOf(inp) === inputs.length - 1) {
                        dismissActivePopover(true);
                        e.preventDefault();
                    }
                }
            });

            inputs.push(inp);
            field.appendChild(lbl);
            field.appendChild(inp);
            popover.appendChild(field);
        });

        popover.style.position = 'fixed';
        popover.style.top = (rect.bottom + 4) + 'px';
        popover.style.right = (window.innerWidth - rect.right) + 'px';

        const slider = this;
        activePopover = {
            el: popover,
            commit: () => {
                const newMin = parseFloat(inputs[0].value);
                const newVal = parseFloat(inputs[1].value);
                const newMax = parseFloat(inputs[2].value);

                if (isNaN(newMin) || isNaN(newVal) || isNaN(newMax)) return;
                if (newMin >= newMax) return;

                slider.updateRange(newMin, newMax);
                slider.setValue(Math.max(newMin, Math.min(newMax, newVal)));
            }
        };

        document.body.appendChild(popover);

        requestAnimationFrame(() => {
            inputs[1].focus();
            inputs[1].select();
        });
    }
}

// ── Section collapse ──

function initSections() {
    document.querySelectorAll('.section-header').forEach((header) => {
        const content = header.nextElementSibling;
        const isExpanded = header.classList.contains('expanded');

        if (!isExpanded) {
            content.classList.add('collapsed');
        }

        header.addEventListener('click', () => {
            const nowExpanded = header.classList.toggle('expanded');
            content.classList.toggle('collapsed', !nowExpanded);
            const arrow = header.querySelector('.section-arrow');
            if (arrow) arrow.textContent = nowExpanded ? '▼' : '▶';
        });
    });
}

// ── Public API ──

function createSlider(containerId, opts) {
    return new SmartSlider(containerId, opts);
}

// ── Debug Slider Infrastructure ──

const DEBUG_SLIDERS = {
    'SIDEBAR FRAME': [
        { id: 'sidebarWidth', swiftId: 'sidebarWidth', label: 'Width', min: 180, max: 500, step: 10, value: 280, unit: 'px' },
        { id: 'sidebarTopInset', swiftId: 'sidebarTopInset', label: 'Top Inset', min: 0, max: 60, step: 2, value: 12, unit: 'px' },
        { id: 'sidebarLeftInset', swiftId: 'sidebarLeftInset', label: 'Left Inset', min: 0, max: 60, step: 2, value: 12, unit: 'px' },
        { id: 'sidebarBottomInset', swiftId: 'sidebarBottomInset', label: 'Bottom Inset', min: 0, max: 60, step: 2, value: 12, unit: 'px' },
        { id: 'panel-blur', cssVar: '--panel-blur', label: 'Panel Blur', min: 0, max: 40, step: 1, value: 16, unit: 'px' },
        { id: 'showAnimDuration', swiftId: 'showAnimDuration', label: 'Show Anim', min: 0.1, max: 1.0, step: 0.05, value: 0.3, unit: 's' },
        { id: 'hideAnimDuration', swiftId: 'hideAnimDuration', label: 'Hide Anim', min: 0.1, max: 1.0, step: 0.05, value: 0.25, unit: 's' }
    ],
    'WINDOW CHROME': [
        { id: 'contentUnderHeader', swiftId: 'contentUnderHeader', label: 'Content Under Header', min: 0, max: 1, step: 1, value: 1 },
        { id: 'headerLocked', swiftId: 'headerLocked', label: 'Lock Header Visible', min: 0, max: 1, step: 1, value: 0 },
        { id: 'dragHandleHeight', swiftId: 'dragHandleHeight', label: 'Header Height', min: 20, max: 60, step: 2, value: 38, unit: 'px' },
        { id: 'trafficLightX', swiftId: 'trafficLightX', label: 'Traffic Light X', min: 0, max: 40, step: 1, value: 8, unit: 'px' },
        { id: 'trafficLightY', swiftId: 'trafficLightY', label: 'Traffic Light Y', min: 0, max: 30, step: 1, value: 8, unit: 'px' },
        { id: 'trafficLightSpacing', swiftId: 'trafficLightSpacing', label: 'Traffic Light Spacing', min: 12, max: 30, step: 1, value: 20, unit: 'px' },
        { id: 'trafficLightScale', swiftId: 'trafficLightScale', label: 'Traffic Light Scale', min: 0.5, max: 2.0, step: 0.05, value: 1.0 },
        { id: 'titleJustification', swiftId: 'titleJustification', label: 'Title Alignment (0=L 1=C 2=R)', min: 0, max: 2, step: 1, value: 1 },
        { id: 'titleOffsetX', swiftId: 'titleOffsetX', label: 'Title X', min: -200, max: 200, step: 2, value: 0, unit: 'px' },
        { id: 'titleOffsetY', swiftId: 'titleOffsetY', label: 'Title Y', min: -15, max: 15, step: 0.5, value: 0, unit: 'px' },
        { id: 'titleOpacity', swiftId: 'titleOpacity', label: 'Title Opacity', min: 0, max: 1, step: 0.05, value: 1.0 },
        { id: 'separatorThickness', swiftId: 'separatorThickness', label: 'Separator Thickness', min: 0, max: 4, step: 0.5, value: 0, unit: 'px' },
        { id: 'separatorOpacity', swiftId: 'separatorOpacity', label: 'Separator Opacity', min: 0, max: 0.5, step: 0.01, value: 0 },
        { id: 'separatorColorR', swiftId: 'separatorColorR', label: 'Separator R', min: 0, max: 255, step: 1, value: 255 },
        { id: 'separatorColorG', swiftId: 'separatorColorG', label: 'Separator G', min: 0, max: 255, step: 1, value: 255 },
        { id: 'separatorColorB', swiftId: 'separatorColorB', label: 'Separator B', min: 0, max: 255, step: 1, value: 255 },
        { id: 'settingsIconScale', swiftId: 'settingsIconScale', label: 'Settings Scale', min: 0.5, max: 2.5, step: 0.05, value: 1.0 },
        { id: 'settingsIconOpacity', swiftId: 'settingsIconOpacity', label: 'Settings Tint Opacity', min: 0, max: 1, step: 0.05, value: 0.35 },
        { id: 'settingsIconXOffset', swiftId: 'settingsIconXOffset', label: 'Settings X', min: -20, max: 20, step: 0.5, value: 0, unit: 'px' },
        { id: 'settingsIconYOffset', swiftId: 'settingsIconYOffset', label: 'Settings Y', min: -10, max: 10, step: 0.5, value: 0, unit: 'px' },
        { id: 'settingsStrokeWeight', swiftId: 'settingsStrokeWeight', label: 'Settings Stroke', min: 1, max: 5, step: 0.5, value: 1 },
        { id: 'settingsRestOpacity', swiftId: 'settingsRestOpacity', label: 'Settings Rest Opacity', min: 0, max: 1, step: 0.05, value: 0.5 },
        { id: 'settingsHoverOpacity', swiftId: 'settingsHoverOpacity', label: 'Settings Hover Opacity', min: 0, max: 1, step: 0.05, value: 1.0 },
        { id: 'portsIconScale', swiftId: 'portsIconScale', label: 'Ports Scale', min: 0.5, max: 2.5, step: 0.05, value: 1.0 },
        { id: 'portsIconXOffset', swiftId: 'portsIconXOffset', label: 'Ports X', min: -20, max: 20, step: 0.5, value: 0, unit: 'px' },
        { id: 'portsIconYOffset', swiftId: 'portsIconYOffset', label: 'Ports Y', min: -10, max: 10, step: 0.5, value: 0, unit: 'px' },
        { id: 'portsStrokeWeight', swiftId: 'portsStrokeWeight', label: 'Ports Stroke', min: 1, max: 5, step: 0.5, value: 1 },
        { id: 'portsRestOpacity', swiftId: 'portsRestOpacity', label: 'Ports Rest Opacity', min: 0, max: 1, step: 0.05, value: 0.5 },
        { id: 'portsHoverOpacity', swiftId: 'portsHoverOpacity', label: 'Ports Hover Opacity', min: 0, max: 1, step: 0.05, value: 1.0 },
        { id: 'refreshIconScale', swiftId: 'refreshIconScale', label: 'Refresh Scale', min: 0.5, max: 2.5, step: 0.05, value: 1.0 },
        { id: 'refreshIconXOffset', swiftId: 'refreshIconXOffset', label: 'Refresh X', min: -20, max: 20, step: 0.5, value: 0, unit: 'px' },
        { id: 'refreshIconYOffset', swiftId: 'refreshIconYOffset', label: 'Refresh Y', min: -10, max: 10, step: 0.5, value: 0, unit: 'px' },
        { id: 'refreshIconOpacity', swiftId: 'refreshIconOpacity', label: 'Refresh Tint Opacity', min: 0, max: 1, step: 0.05, value: 0.35 },
        { id: 'refreshStrokeWeight', swiftId: 'refreshStrokeWeight', label: 'Refresh Stroke', min: 1, max: 5, step: 0.5, value: 2 },
        { id: 'refreshRestOpacity', swiftId: 'refreshRestOpacity', label: 'Refresh Rest Opacity', min: 0, max: 1, step: 0.05, value: 0.5 },
        { id: 'refreshHoverOpacity', swiftId: 'refreshHoverOpacity', label: 'Refresh Hover Opacity', min: 0, max: 1, step: 0.05, value: 1.0 },
        { id: 'fullBleedIconScale', swiftId: 'fullBleedIconScale', label: 'Toggle Scale', min: 0.5, max: 2.5, step: 0.05, value: 1.0 },
        { id: 'fullBleedIconXOffset', swiftId: 'fullBleedIconXOffset', label: 'Toggle X', min: -20, max: 20, step: 0.5, value: 0, unit: 'px' },
        { id: 'fullBleedIconYOffset', swiftId: 'fullBleedIconYOffset', label: 'Toggle Y', min: -10, max: 10, step: 0.5, value: 0, unit: 'px' },
        { id: 'fullBleedIconOpacity', swiftId: 'fullBleedIconOpacity', label: 'Toggle Tint Opacity', min: 0, max: 1, step: 0.05, value: 0.35 },
        { id: 'fullBleedStrokeWeight', swiftId: 'fullBleedStrokeWeight', label: 'Toggle Stroke', min: 1, max: 5, step: 0.5, value: 1 },
        { id: 'fullBleedRestOpacity', swiftId: 'fullBleedRestOpacity', label: 'Toggle Rest Opacity', min: 0, max: 1, step: 0.05, value: 0.5 },
        { id: 'fullBleedHoverOpacity', swiftId: 'fullBleedHoverOpacity', label: 'Toggle Hover Opacity', min: 0, max: 1, step: 0.05, value: 1.0 }
    ],
    TYPOGRAPHY: [
        { id: 'title-size', cssVar: '--title-size', label: 'Title Size', min: 4, max: 24, step: 1, value: 10, unit: 'px' },
        { id: 'title-weight', cssVar: '--title-weight', label: 'Title Weight', min: 100, max: 900, step: 100, value: 400 },
        { id: 'title-letter-spacing', cssVar: '--title-letter-spacing', label: 'Title Letter Spacing', min: 0, max: 5, step: 0.1, value: 2.5, unit: 'px' },
        { id: 'section-title-size', cssVar: '--section-title-size', label: 'Section Title Size', min: 6, max: 20, step: 1, value: 12, unit: 'px' },
        { id: 'section-title-spacing', cssVar: '--section-title-spacing', label: 'Section Title Spacing', min: 0, max: 4, step: 0.1, value: 1, unit: 'px' },
        { id: 'label-letter-spacing', cssVar: '--label-letter-spacing', label: 'Label Letter Spacing', min: 0, max: 3, step: 0.1, value: 0.5, unit: 'px' },
        { id: 'section-arrow-size', cssVar: '--section-arrow-size', label: 'Section Arrow Size', min: 4, max: 16, step: 1, value: 8, unit: 'px' },
        { id: 'param-label-size', cssVar: '--param-label-size', label: 'Param Label Size', min: 4, max: 16, step: 1, value: 8, unit: 'px' },
        { id: 'value-size', cssVar: '--value-size', label: 'Value Size', min: 4, max: 16, step: 1, value: 8, unit: 'px' }
    ],
    SPACING: [
        { id: 'title-pad-top', cssVar: '--title-pad-top', label: 'Title Pad Top', min: 0, max: 30, step: 1, value: 14, unit: 'px' },
        { id: 'title-pad-bottom', cssVar: '--title-pad-bottom', label: 'Title Pad Bottom', min: 0, max: 60, step: 1, value: 8, unit: 'px' },
        { id: 'ctrl-pad-left', cssVar: '--ctrl-pad-left', label: 'Content Pad Left', min: 0, max: 30, step: 1, value: 14, unit: 'px' },
        { id: 'ctrl-pad-right', cssVar: '--ctrl-pad-right', label: 'Content Pad Right', min: 0, max: 30, step: 1, value: 14, unit: 'px' },
        { id: 'ctrl-mb', cssVar: '--ctrl-mb', label: 'Control Margin Bottom', min: 0, max: 20, step: 1, value: 6, unit: 'px' },
        { id: 'section-between-gap', cssVar: '--section-between-gap', label: 'Section Gap', min: 0, max: 20, step: 1, value: 5, unit: 'px' },
        { id: 'header-content-gap', cssVar: '--header-content-gap', label: 'Header Content Gap', min: 0, max: 20, step: 1, value: 5, unit: 'px' },
        { id: 'section-header-pad', cssVar: '--section-header-pad', label: 'Section Header Pad', min: 0, max: 12, step: 1, value: 10, unit: 'px' },
        { id: 'section-arrow-margin', cssVar: '--section-arrow-margin', label: 'Arrow Margin', min: 0, max: 12, step: 1, value: 5, unit: 'px' },
        { id: 'scroll-pad-bottom', cssVar: '--scroll-pad-bottom', label: 'Scroll Pad Bottom', min: 0, max: 40, step: 1, value: 10, unit: 'px' }
    ],
    SLIDERS: [
        { id: 'slider-track-h', cssVar: '--slider-track-h', label: 'Track Height', min: 0.5, max: 6, step: 0.5, value: 1.5, unit: 'px' },
        { id: 'track-radius', cssVar: '--track-radius', label: 'Track Radius', min: 0, max: 4, step: 0.5, value: 1, unit: 'px' },
        { id: 'thumb-w', cssVar: '--thumb-w', label: 'Thumb Width', min: 4, max: 24, step: 1, value: 10, unit: 'px' },
        { id: 'thumb-h', cssVar: '--thumb-h', label: 'Thumb Height', min: 4, max: 24, step: 1, value: 10, unit: 'px' },
        { id: 'thumb-scale', cssVar: '--thumb-scale', label: 'Thumb Scale', min: 0.5, max: 3, step: 0.1, value: 1 },
        { id: 'slider-row-gap', cssVar: '--slider-row-gap', label: 'Row Gap', min: 0, max: 16, step: 1, value: 6, unit: 'px' },
        { id: 'slider-container-gap', cssVar: '--slider-container-gap', label: 'Container Gap', min: 0, max: 10, step: 1, value: 2, unit: 'px' },
        { id: 'slider-input-height', cssVar: '--slider-input-height', label: 'Input Height', min: 8, max: 32, step: 1, value: 16, unit: 'px' },
        { id: 'value-min-width', cssVar: '--value-min-width', label: 'Value Min Width', min: 20, max: 80, step: 2, value: 36, unit: 'px' }
    ],
    SCROLLBAR: [
        { id: 'scrollbar-w', cssVar: '--scrollbar-w', label: 'Width', min: 1, max: 12, step: 1, value: 4, unit: 'px' },
        { id: 'scrollbar-radius', cssVar: '--scrollbar-radius', label: 'Radius', min: 0, max: 6, step: 1, value: 2, unit: 'px' },
        { id: 'scrollbar-opacity', cssVar: '--scrollbar-opacity', label: 'Thumb Opacity', min: 0, max: 1, step: 0.01, value: 0.08 },
        { id: 'scrollbar-hover-opacity', cssVar: '--scrollbar-hover-opacity', label: 'Thumb Hover Opacity', min: 0, max: 1, step: 0.01, value: 0.18 },
        { id: 'scrollbar-track-opacity', cssVar: '--scrollbar-track-opacity', label: 'Track Opacity', min: 0, max: 1, step: 0.01, value: 0 }
    ],
    POPOVER: [
        { id: 'popover-gap', cssVar: '--popover-gap', label: 'Gap', min: 0, max: 16, step: 1, value: 6, unit: 'px' },
        { id: 'popover-pad-v', cssVar: '--popover-pad-v', label: 'Pad V', min: 0, max: 20, step: 1, value: 8, unit: 'px' },
        { id: 'popover-pad-h', cssVar: '--popover-pad-h', label: 'Pad H', min: 0, max: 20, step: 1, value: 10, unit: 'px' },
        { id: 'popover-bg-opacity', cssVar: '--popover-bg-opacity', label: 'BG Opacity', min: 0.5, max: 1, step: 0.01, value: 0.95 },
        { id: 'popover-radius', cssVar: '--popover-radius', label: 'Radius', min: 0, max: 16, step: 1, value: 6, unit: 'px' },
        { id: 'popover-blur', cssVar: '--popover-blur', label: 'Blur', min: 0, max: 30, step: 1, value: 12, unit: 'px' },
        { id: 'edit-input-width', cssVar: '--edit-input-width', label: 'Input Width', min: 30, max: 100, step: 2, value: 52, unit: 'px' },
        { id: 'edit-input-size', cssVar: '--edit-input-size', label: 'Input Size', min: 6, max: 16, step: 1, value: 10, unit: 'px' },
        { id: 'edit-input-radius', cssVar: '--edit-input-radius', label: 'Input Radius', min: 0, max: 10, step: 1, value: 3, unit: 'px' },
        { id: 'edit-label-size', cssVar: '--edit-label-size', label: 'Label Size', min: 4, max: 14, step: 1, value: 8, unit: 'px' }
    ],
    'PORT BROWSER': [
        { id: 'scanlineOpacity', swiftId: 'scanlineOpacity', label: 'Scanline Opacity', min: 0, max: 0.3, step: 0.01, value: 0.08 },
        { id: 'scanlineSpacing', swiftId: 'scanlineSpacing', label: 'Scanline Spacing', min: 1, max: 10, step: 1, value: 4, unit: 'px' },
        { id: 'scanlineThickness', swiftId: 'scanlineThickness', label: 'Scanline Thickness', min: 1, max: 6, step: 1, value: 2, unit: 'px' },
        { id: 'showGreenDot', swiftId: 'showGreenDot', label: 'Show Status Dot', min: 0, max: 1, step: 1, value: 0 }
    ]
};

function initDebugSliders() {
    const debugSection = document.getElementById('debug-section');
    if (!debugSection) return;

    Object.keys(DEBUG_SLIDERS).forEach((sectionName) => {
        const sliders = DEBUG_SLIDERS[sectionName];

        const section = document.createElement('div');
        section.className = 'section';

        const header = document.createElement('div');
        header.className = 'section-header';

        const arrow = document.createElement('span');
        arrow.className = 'section-arrow';
        arrow.textContent = '▶';

        const title = document.createElement('span');
        title.className = 'section-title';
        title.textContent = sectionName;

        header.appendChild(arrow);
        header.appendChild(title);

        const content = document.createElement('div');
        content.className = 'section-content collapsed';

        header.addEventListener('click', () => {
            const nowExpanded = header.classList.toggle('expanded');
            content.classList.toggle('collapsed', !nowExpanded);
            arrow.textContent = nowExpanded ? '▼' : '▶';
        });

        // Create slider container divs
        sliders.forEach((cfg) => {
            const containerDiv = document.createElement('div');
            containerDiv.className = 'slider-container';
            containerDiv.id = 'debug-slider-' + cfg.id;
            content.appendChild(containerDiv);
        });

        section.appendChild(header);
        section.appendChild(content);
        // CRITICAL: append to DOM BEFORE creating sliders
        debugSection.appendChild(section);

        // NOW create sliders (getElementById will find them)
        sliders.forEach((cfg) => {
            const containerId = 'debug-slider-' + cfg.id;
            const unit = cfg.unit || '';

            createSlider(containerId, {
                id: cfg.id,
                label: cfg.label,
                min: cfg.min,
                max: cfg.max,
                step: cfg.step,
                value: cfg.value,
                onChange: function(val) {
                    if (cfg.cssVar) {
                        document.body.style.setProperty(cfg.cssVar, val + unit);
                        if (cfg.id === 'panel-opacity') {
                            var rgb = document.body.getAttribute('data-inverted') === 'true'
                                ? '245, 245, 245' : '18, 18, 18';
                            document.body.style.setProperty('--panel-bg', 'rgba(' + rgb + ', ' + val + ')');
                        }
                        sendToSwift({ type: 'debug', id: cfg.id, value: val });
                    } else if (cfg.swiftId) {
                        sendToSwift({ type: 'debug', id: cfg.swiftId, value: val });
                    }
                }
            });
        });

        // Add font picker dropdown after TYPOGRAPHY sliders
        if (sectionName === 'TYPOGRAPHY') {
            const fontContainer = document.createElement('div');
            fontContainer.className = 'dropdown-container';

            const fontLabel = document.createElement('div');
            fontLabel.className = 'ui-label';
            fontLabel.textContent = 'FONT';

            const fontRow = document.createElement('div');
            fontRow.className = 'dropdown-row';

            const fontDisplay = document.createElement('div');
            fontDisplay.className = 'dropdown-display';
            fontDisplay.textContent = 'Menlo';

            const fontSelect = document.createElement('select');
            const macFonts = [
                'Menlo', 'Monaco', 'Courier New', 'Helvetica Neue', 'Helvetica',
                'Arial', 'Georgia', 'Times New Roman', 'Verdana', 'Trebuchet MS',
                'Palatino', 'Optima', 'Futura', 'Avenir', 'Avenir Next',
                'Gill Sans', 'Didot', 'Baskerville', 'American Typewriter', 'Copperplate'
            ];
            macFonts.forEach(function(f) {
                const opt = document.createElement('option');
                opt.value = f;
                opt.textContent = f;
                fontSelect.appendChild(opt);
            });
            fontSelect.value = 'Menlo';

            fontSelect.addEventListener('change', function() {
                const chosen = fontSelect.value;
                fontDisplay.textContent = chosen;
                document.body.style.setProperty('--font-family', "'" + chosen + "', sans-serif");
                sendToSwift({ type: 'debug', id: 'font-family', value: chosen });
            });

            fontRow.appendChild(fontDisplay);
            fontRow.appendChild(fontSelect);
            fontContainer.appendChild(fontLabel);
            fontContainer.appendChild(fontRow);
            content.appendChild(fontContainer);
        }

        // Add scrollbar color picker after SCROLLBAR sliders
        if (sectionName === 'SCROLLBAR') {
            const sbColorContainer = document.createElement('div');
            sbColorContainer.className = 'color-picker-container';

            const sbColorLabel = document.createElement('div');
            sbColorLabel.className = 'ui-label';
            sbColorLabel.textContent = 'SCROLLBAR COLOR';

            const sbColorRow = document.createElement('div');
            sbColorRow.className = 'color-picker-row';

            const sbColorInput = document.createElement('input');
            sbColorInput.type = 'color';
            sbColorInput.value = '#ffffff';

            sbColorInput.addEventListener('input', function() {
                const hex = sbColorInput.value;
                const r = parseInt(hex.substr(1, 2), 16);
                const g = parseInt(hex.substr(3, 2), 16);
                const b = parseInt(hex.substr(5, 2), 16);
                const op = getComputedStyle(document.body).getPropertyValue('--scrollbar-opacity').trim() || '0.08';
                const hop = getComputedStyle(document.body).getPropertyValue('--scrollbar-hover-opacity').trim() || '0.18';
                const top = getComputedStyle(document.body).getPropertyValue('--scrollbar-track-opacity').trim() || '0';
                document.body.style.setProperty('--scrollbar', 'rgba(' + r + ',' + g + ',' + b + ',' + op + ')');
                document.body.style.setProperty('--scrollbar-hover', 'rgba(' + r + ',' + g + ',' + b + ',' + hop + ')');
                document.body.style.setProperty('--scrollbar-track-bg', 'rgba(' + r + ',' + g + ',' + b + ',' + top + ')');
                sendToSwift({ type: 'debug', id: 'scrollbar-color', value: hex });
            });

            sbColorRow.appendChild(sbColorLabel);
            sbColorRow.appendChild(sbColorInput);
            sbColorContainer.appendChild(sbColorRow);
            content.appendChild(sbColorContainer);
        }
    });
}

function toggleDebug() {
    const debugSection = document.getElementById('debug-section');
    const separator = document.getElementById('debug-separator');
    const defaultsSection = document.getElementById('defaults-section');
    if (!debugSection) return false;

    const isVisible = debugSection.classList.toggle('visible');

    if (separator) {
        separator.style.display = isVisible ? 'block' : 'none';
    }
    if (defaultsSection) {
        defaultsSection.style.display = isVisible ? 'block' : 'none';
    }

    return isVisible;
}
