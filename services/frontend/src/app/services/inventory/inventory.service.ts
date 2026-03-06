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

  private apiUrl = 'http://10.10.10.11:30900/api/inventory';


  constructor(private http: HttpClient) {}

  addInventory(request: InventoryRequest): Observable<void> {
    return this.http.post<void>(this.apiUrl, request);
  }
}
