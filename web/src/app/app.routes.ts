import { Routes } from '@angular/router';
import { authGuard } from './core/auth.guard';
import { LoginComponent } from './layout/login.component';
import { ShellComponent } from './layout/shell.component';

export const routes: Routes = [
  { path: 'login', component: LoginComponent },
  {
    path: '',
    component: ShellComponent,
    canActivate: [authGuard],
    children: [
      { path: '', redirectTo: 'webapps', pathMatch: 'full' },
      { path: 'webapps', loadComponent: () => import('./webapps/webapps.component').then((m) => m.WebappsComponent) },
      { path: 'webapps/explorer', loadComponent: () => import('./webapps/explorer.component').then((m) => m.ExplorerComponent) },
      { path: 'permissions', loadComponent: () => import('./permissions/permissions.component').then((m) => m.PermissionsComponent) },
      { path: 'security', loadComponent: () => import('./security/security.component').then((m) => m.SecurityComponent) },
      { path: 'tasks', loadComponent: () => import('./tasks/tasks.component').then((m) => m.TasksComponent) },
      { path: 'system', loadComponent: () => import('./system/system.component').then((m) => m.SystemComponent) },
      { path: 'logs', loadComponent: () => import('./logs/logs.component').then((m) => m.LogsComponent) },
    ],
  },
  { path: '**', redirectTo: 'webapps' },
];