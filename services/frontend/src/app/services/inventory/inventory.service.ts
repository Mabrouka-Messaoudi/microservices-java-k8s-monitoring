import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface InventoryRequest {
  skuCode: string;
  quantity: number;
}

@Injectable({
  providedIn: 'root'
})
export class InventoryService {

  private apiUrl: string;

  constructor(private http: HttpClient) {
    const env = (window as any).__ENV__ || {};
    this.apiUrl = (env.API_GATEWAY_URL || 'http://localhost:30900') + '/api/inventory';
  }

  addInventory(request: InventoryRequest): Observable<void> {
    return this.http.post<void>(this.apiUrl, request);
  }
}
