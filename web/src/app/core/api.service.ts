import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class ApiService {
  private readonly base: string;

  constructor(private http: HttpClient) {
    this.base = '/api/mp';
  }

  get<T>(path: string, params?: Record<string, string | number>): Observable<T> {
    let p = new HttpParams();
    if (params) {
      for (const key of Object.keys(params)) {
        p = p.set(key, String(params[key]));
      }
    }
    return this.http.get<T>(`${this.base}${path}`, { params: p });
  }

  post<T>(path: string, body?: unknown, headers?: HttpHeaders): Observable<T> {
    const req = this.body64(`${this.base}${path}`, body ?? {});
    const h = (headers ?? new HttpHeaders()).set('Content-Type', 'text/plain');
    return this.http.post<T>(req.url, req.body, { headers: h });
  }

  put<T>(path: string, body?: unknown): Observable<T> {
    const req = this.body64(`${this.base}${path}`, body ?? {});
    return this.http.put<T>(req.url, req.body);
  }

  /** The 2026.1 CSP gateway corrupts POST bodies (strips double quotes), so JSON is
      transported as base64 in a query parameter and the request body is left empty. */
  private body64(baseUrl: string, body: unknown): { url: string; body: string } {
    const json = JSON.stringify(body);
    const b64 = btoa(unescape(encodeURIComponent(json)));
    const sep = baseUrl.indexOf('?') >= 0 ? '&' : '?';
    return { url: `${baseUrl}${sep}body64=${encodeURIComponent(b64)}`, body: '' };
  }

  delete<T>(path: string, params?: Record<string, string | number>): Observable<T> {
    let p = new HttpParams();
    if (params) {
      for (const key of Object.keys(params)) {
        p = p.set(key, String(params[key]));
      }
    }
    return this.http.delete<T>(`${this.base}${path}`, { params: p });
  }

  raw(path: string, params?: Record<string, string | number>): Observable<string> {
    let p = new HttpParams();
    if (params) {
      for (const key of Object.keys(params)) {
        p = p.set(key, String(params[key]));
      }
    }
    return this.http.get(`${this.base}${path}`, { params: p, responseType: 'text' });
  }

  url(path: string): string {
    return `${this.base}${path}`;
  }
}