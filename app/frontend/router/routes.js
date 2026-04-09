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
    path: '/:pathMatch(.*)*',
    name: 'NotFound',
    component: () => import('../pages/NotFound.vue'),
  },
]
