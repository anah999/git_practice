/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
// @ts-check
"use strict";

(function () {

	/**
	 * @param {number} value
	 * @param {number} min
	 * @param {number} max
	 * @return {number}
	 */
	function clamp(value, min, max) {
		return Math.min(Math.max(value, min), max);
	}

	function getSettings() {
		const element = document.getElementById('preview-mp4-settings');
		if (element) {
			const data = element.getAttribute('data-settings');
			if (data) {
				return JSON.parse(data);
			}
		}

		throw new Error(`Could not load settings`);
	}

	function setVideoSrc(url) {
		var req = new XMLHttpRequest();
		req.open('GET', url, true);
		req.responseType = "blob";
		req.onload = function (e) {
			if (req.status == 200) {
				var obj = URL.createObjectURL(req.response)
				video.src = obj;
			}
		};
		req.send();
	}

	/**
	 * Enable video-rendering: pixelated for videos scaled by more than this.
	 */
	const PIXELATION_THRESHOLD = 3;

	const SCALE_PINCH_FACTOR = 0.075;
	const MAX_SCALE = 20;
	const MIN_SCALE = 0.1;

	const zoomLevels = [
		0.1,
		0.2,
		0.3,
		0.4,
		0.5,
		0.6,
		0.7,
		0.8,
		0.9,
		1,
		1.5,
		2,
		3,
		5,
		7,
		10,
		15,
		20
	];

	const settings = getSettings();
	const isMac = settings.isMac;

	const vscode = acquireVsCodeApi();

	const initialState = vscode.getState() || { scale: 'fit', offsetX: 0, offsetY: 0 };

	// State
	let scale = initialState.scale;
	let ctrlPressed = false;
	let altPressed = false;
	let hasLoadedVideo = false;
	let consumeClick = true;
	let isActive = false;

	// Elements
	const container = document.body;
	const video = document.createElement('video');
	video.autoplay = settings.autoplay;
	video.loop     = settings.loop;
	video.controls = settings.controls;

	function updateScale(newScale) {
		if (!video || !hasLoadedVideo || !video.parentElement) {
			return;
		}

		if (newScale === 'fit') {
			scale = 'fit';
			video.classList.add('scale-to-fit');
			video.classList.remove('pixelated');
			video.style.minWidth = 'auto';
			video.style.width = 'auto';
			vscode.setState(undefined);
		} else {
			scale = clamp(newScale, MIN_SCALE, MAX_SCALE);
			if (scale >= PIXELATION_THRESHOLD) {
				video.classList.add('pixelated');
			} else {
				video.classList.remove('pixelated');
			}

			const dx = (window.scrollX + container.clientWidth / 2) / container.scrollWidth;
			const dy = (window.scrollY + container.clientHeight / 2) / container.scrollHeight;

			video.classList.remove('scale-to-fit');
			video.style.minWidth = `${(video.videoWidth * scale)}px`;
			video.style.width = `${(video.videoWidth * scale)}px`;

			const newScrollX = container.scrollWidth * dx - container.clientWidth / 2;
			const newScrollY = container.scrollHeight * dy - container.clientHeight / 2;

			window.scrollTo(newScrollX, newScrollY);

			vscode.setState({ scale: scale, offsetX: newScrollX, offsetY: newScrollY });
		}

		vscode.postMessage({
			type: 'zoom',
			value: scale
		});
	}

	function setActive(value) {
		isActive = value;
		if (value) {
			if (isMac ? altPressed : ctrlPressed) {
				container.classList.remove('zoom-in');
				container.classList.add('zoom-out');
			} else {
				container.classList.remove('zoom-out');
				container.classList.add('zoom-in');
			}
		} else {
			ctrlPressed = false;
			altPressed = false;
			container.classList.remove('zoom-out');
			container.classList.remove('zoom-in');
		}
	}

	function firstZoom() {
		if (!video || !hasLoadedVideo) {
			return;
		}

		scale = video.clientWidth / video.videoWidth;
		updateScale(scale);
	}

	function zoomIn() {
		if (scale === 'fit') {
			firstZoom();
		}

		let i = 0;
		for (; i < zoomLevels.length; ++i) {
			if (zoomLevels[i] > scale) {
				break;
			}
		}
		updateScale(zoomLevels[i] || MAX_SCALE);
	}

	function zoomOut() {
		if (scale === 'fit') {
			firstZoom();
		}

		let i = zoomLevels.length - 1;
		for (; i >= 0; --i) {
			if (zoomLevels[i] < scale) {
				break;
			}
		}
		updateScale(zoomLevels[i] || MIN_SCALE);
	}

	window.addEventListener('keydown', (/** @type {KeyboardEvent} */ e) => {
		if (!video || !hasLoadedVideo) {
			return;
		}
		ctrlPressed = e.ctrlKey;
		altPressed = e.altKey;

		if (isMac ? altPressed : ctrlPressed) {
			container.classList.remove('zoom-in');
			container.classList.add('zoom-out');
		}
	});

	window.addEventListener('keyup', (/** @type {KeyboardEvent} */ e) => {
		if (!video || !hasLoadedVideo) {
			return;
		}

		ctrlPressed = e.ctrlKey;
		altPressed = e.altKey;

		if (!(isMac ? altPressed : ctrlPressed)) {
			container.classList.remove('zoom-out');
			container.classList.add('zoom-in');
		}
	});

	container.addEventListener('mousedown', (/** @type {MouseEvent} */ e) => {
		if (!video || !hasLoadedVideo) {
			return;
		}

		if (e.button !== 0) {
			return;
		}

		ctrlPressed = e.ctrlKey;
		altPressed = e.altKey;

		consumeClick = !isActive;
	});

	container.addEventListener('click', (/** @type {MouseEvent} */ e) => {
		if (!video || !hasLoadedVideo) {
			return;
		}

		if (e.button !== 0) {
			return;
		}

		if (consumeClick) {
			consumeClick = false;
			return;
		}
		// left click
		if (scale === 'fit') {
			firstZoom();
		}

		if (!(isMac ? altPressed : ctrlPressed)) { // zoom in
			zoomIn();
		} else {
			zoomOut();
		}
	});

	container.addEventListener('wheel', (/** @type {WheelEvent} */ e) => {
		// Prevent pinch to zoom
		if (e.ctrlKey) {
			e.preventDefault();
		}

		if (!video || !hasLoadedVideo) {
			return;
		}

		const isScrollWheelKeyPressed = isMac ? altPressed : ctrlPressed;
		if (!isScrollWheelKeyPressed && !e.ctrlKey) { // pinching is reported as scroll wheel + ctrl
			return;
		}

		if (scale === 'fit') {
			firstZoom();
		}

		let delta = e.deltaY > 0 ? 1 : -1;
		updateScale(scale * (1 - delta * SCALE_PINCH_FACTOR));
	}, { passive: false });

	window.addEventListener('scroll', e => {
		if (!video || !hasLoadedVideo || !video.parentElement || scale === 'fit') {
			return;
		}

		const entry = vscode.getState();
		if (entry) {
			vscode.setState({ scale: entry.scale, offsetX: window.scrollX, offsetY: window.scrollY });
		}
	}, { passive: true });

	container.classList.add('video');

	video.classList.add('scale-to-fit');

	video.addEventListener('canplay', () => {
		if (hasLoadedVideo) {
			return;
		}
		hasLoadedVideo = true;

		vscode.postMessage({
			type: 'size',
			value: `${video.videoWidth}x${video.videoHeight}`,
		});

		document.body.classList.remove('loading');
		document.body.classList.add('ready');
		document.body.append(video);

		updateScale(scale);

		if (initialState.scale !== 'fit') {
			window.scrollTo(initialState.offsetX, initialState.offsetY);
		}
	});

	video.addEventListener('error', e => {
		if (hasLoadedVideo) {
			return;
		}

		hasLoadedVideo = true;
		document.body.classList.add('error');
		document.body.classList.remove('loading');
	});

	//setVideoSrc(settings.src);
	video.src = settings.src

	document.querySelector('.open-file-link').addEventListener('click', () => {
		vscode.postMessage({
			type: 'reopen-as-text',
		});
	});

	window.addEventListener('message', e => {
		switch (e.data.type) {
			case 'setScale':
				updateScale(e.data.scale);
				break;

			case 'setActive':
				setActive(e.data.value);
				break;

			case 'zoomIn':
				zoomIn();
				break;

			case 'zoomOut':
				zoomOut();
				break;
		}
	});
}());
