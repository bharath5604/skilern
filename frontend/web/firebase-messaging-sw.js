/* eslint-disable no-undef */

importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
    apiKey: 'AIzaSyD4YwfBkdMz2JKFIpRXdcpz5dhLbHO9BII',
    appId: '1:64177655201:web:476ff16e8de805d8de8fe0',
    messagingSenderId: '64177655201',
    projectId: 'skilern-8571f',
    authDomain: 'skilern-8571f.firebaseapp.com',
    storageBucket: 'skilern-8571f.firebasestorage.app',
    measurementId: 'G-SDQLJWR4XS',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);

  const notificationTitle = payload.notification?.title || 'Skilern';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/favicon.png',
  };

  // eslint-disable-next-line no-restricted-globals
  self.registration.showNotification(notificationTitle, notificationOptions);
});