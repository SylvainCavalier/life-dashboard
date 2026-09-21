// app/frontend/router/routes.js
export default [
  {
    path: '/',
    name: 'Dashboard',
    component: () => import('../pages/Dashboard.vue'),
  },
  {
    path: '/contacts',
    name: 'Contacts',
    component: () => import('../pages/modules/ContactsPage.vue'),
  },
  {
    path: '/crm',
    name: 'Crm',
    component: () => import('../pages/modules/CrmPage.vue'),
  },
  {
    path: '/properties',
    name: 'Properties',
    component: () => import('../pages/modules/PropertiesPage.vue'),
  },
  {
    path: '/companies',
    name: 'Companies',
    component: () => import('../pages/modules/CompaniesPage.vue'),
  },
  {
    path: '/companies/:id',
    name: 'CompanyShow',
    component: () => import('../pages/modules/CompanyShowPage.vue'),
    props: true,
  },
  {
    path: '/budget',
    name: 'Budget',
    component: () => import('../pages/modules/BudgetPage.vue'),
  },
  {
    path: '/activities',
    name: 'Activities',
    component: () => import('../pages/modules/ActivitiesPage.vue'),
  },
  {
    path: '/languages',
    name: 'Languages',
    component: () => import('../pages/modules/LanguagesPage.vue'),
  },
  {
    path: '/agenda',
    name: 'Agenda',
    component: () => import('../pages/modules/AgendaPage.vue'),
  },
  {
    path: '/passwords',
    name: 'Passwords',
    component: () => import('../pages/modules/PasswordsPage.vue'),
  },
  {
    path: '/profile',
    name: 'Profile',
    component: () => import('../pages/modules/ProfilePage.vue'),
  },
  {
    path: '/health',
    name: 'Health',
    component: () => import('../pages/modules/HealthPage.vue'),
  },
  {
    path: '/subscriptions',
    name: 'Subscriptions',
    component: () => import('../pages/modules/SubscriptionsPage.vue'),
  },
  {
    path: '/mails',
    name: 'Mails',
    component: () => import('../pages/modules/MailsPage.vue'),
  },
  {
    path: '/notes',
    name: 'Notes',
    component: () => import('../pages/modules/NotesPage.vue'),
  },
  {
    path: '/useful-sites',
    name: 'UsefulSites',
    component: () => import('../pages/modules/UsefulSitesPage.vue'),
  },
  {
    path: '/projects',
    name: 'Projects',
    component: () => import('../pages/modules/ProjectsPage.vue'),
  },
  {
    path: '/projects/:id',
    name: 'ProjectShow',
    component: () => import('../pages/modules/ProjectShowPage.vue'),
  },
  {
    path: '/cv',
    name: 'CV',
    component: () => import('../pages/modules/CVPage.vue'),
  },
  {
    path: '/documents',
    name: 'Documents',
    component: () => import('../pages/modules/DocumentsPage.vue'),
  },
  {
    path: '/transfer',
    name: 'Transfer',
    component: () => import('../pages/modules/TransferPage.vue'),
  },
  {
    path: '/downloader',
    name: 'Downloader',
    component: () => import('../pages/modules/DownloaderPage.vue'),
  },
  {
    path: '/downloader/folders/:id',
    name: 'DownloaderFolder',
    component: () => import('../pages/modules/DownloaderFolderPage.vue'),
  },
  {
    path: '/trips',
    name: 'Trips',
    component: () => import('../pages/modules/TripsPage.vue'),
  },
  {
    path: '/trips/:id',
    name: 'TripShow',
    component: () => import('../pages/modules/TripShowPage.vue'),
    props: true,
  },
  {
    path: '/:pathMatch(.*)*',
    name: 'NotFound',
    component: () => import('../pages/NotFound.vue'),
  },
]
