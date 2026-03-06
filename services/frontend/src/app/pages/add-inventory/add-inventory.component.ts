import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { InventoryService } from '../../services/inventory/inventory.service';

@Component({
  selector: 'app-add-inventory',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './add-inventory.component.html',
  styleUrls: ['./add-inventory.component.css']
})
export class AddInventoryComponent {

  addInventoryForm: FormGroup;
  inventoryCreated = false;
  submitFailed = false;
  isSubmitting = false;

  constructor(
    private fb: FormBuilder,
    private inventoryService: InventoryService,
    private router: Router
  ) {
    this.addInventoryForm = this.fb.group({
      skuCode: ['', [Validators.required, Validators.minLength(3)]],
      quantity: [null, [Validators.required, Validators.min(1)]]
    });
  }

  get skuCode() { return this.addInventoryForm.get('skuCode'); }
  get quantity() { return this.addInventoryForm.get('quantity'); }

  onSubmit(): void {
    if (this.addInventoryForm.invalid) return;

    this.isSubmitting = true;
    this.inventoryCreated = false;
    this.submitFailed = false;

    this.inventoryService.addInventory(this.addInventoryForm.value).subscribe({
      next: () => {
        this.inventoryCreated = true;
        this.isSubmitting = false;
        this.addInventoryForm.reset();
      },
      error: () => {
        this.submitFailed = true;
        this.isSubmitting = false;
      }
    });
  }

  goBack(): void {
    this.router.navigate(['/']);
  }
}
