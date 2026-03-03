// app/frontend/router/routes.js
export default [
  {
    path: '/',
    name: 'Dashboard',
    component: () => import('../pages/Dashboard.vue'),
  },
  // Add your routes here
  // Example with auth guard:
  // {
  //   path: '/profile',
  //   name: 'Profile',
  //   component: () => import('../pages/Profile.vue'),
  //   meta: { requiresAuth: true },
  // },
  {
    path: '/:pathMatch(.*)*',
    name: 'NotFound',
    component: () => import('../pages/NotFound.vue'),
  },
]
