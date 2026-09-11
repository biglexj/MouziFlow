import React, { useState, useRef, useEffect } from "react";
import { ChevronDown, Check } from "lucide-react";

export interface SelectOption<T = string> {
  value: T;
  label: string;
  icon?: React.ReactNode;
  description?: string;
}

interface CustomSelectProps<T = string> {
  value: T;
  onChange: (value: T) => void;
  options: SelectOption<T>[];
  placeholder?: string;
  className?: string;
  buttonClassName?: string;
  menuClassName?: string;
  icon?: React.ReactNode;
  disabled?: boolean;
  size?: "sm" | "md";
}

export default function CustomSelect<T extends string | number>({
  value,
  onChange,
  options,
  placeholder,
  className = "",
  buttonClassName = "",
  menuClassName = "",
  icon,
  disabled = false,
  size = "sm",
}: CustomSelectProps<T>) {
  const [isOpen, setIsOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  const selectedOption = options.find((opt) => opt.value === value);

  // Close dropdown on click outside or Escape
  useEffect(() => {
    if (!isOpen) return;

    const handleClickOutside = (event: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setIsOpen(false);
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    document.addEventListener("keydown", handleKeyDown);

    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [isOpen]);

  const handleSelect = (optionValue: T) => {
    onChange(optionValue);
    setIsOpen(false);
  };

  const isSmall = size === "sm";

  return (
    <div
      ref={containerRef}
      className={`relative inline-block w-full select-none ${className}`}
      data-no-drag
    >
      {/* Trigger Button */}
      <button
        type="button"
        disabled={disabled}
        onClick={() => !disabled && setIsOpen((prev) => !prev)}
        className={`w-full flex items-center justify-between gap-1.5 rounded-md border border-border bg-surface-dark transition-all duration-150 outline-none text-left ${
          isSmall ? "px-2.5 py-1 text-xs" : "px-3 py-2 text-sm"
        } ${
          isOpen
            ? "border-primary ring-1 ring-primary/30"
            : "hover:border-border-hover hover:bg-surface"
        } ${disabled ? "opacity-50 cursor-not-allowed" : "cursor-pointer"} ${buttonClassName}`}
      >
        <div className="flex items-center gap-1.5 truncate min-w-0">
          {icon ? (
            <span className="shrink-0 text-text-muted">{icon}</span>
          ) : selectedOption?.icon ? (
            <span className="shrink-0">{selectedOption.icon}</span>
          ) : null}
          <span className="truncate font-medium text-text">
            {selectedOption ? selectedOption.label : placeholder || ""}
          </span>
        </div>
        <ChevronDown
          size={isSmall ? 13 : 15}
          className={`text-text-muted shrink-0 transition-transform duration-200 ${
            isOpen ? "rotate-180 text-primary" : ""
          }`}
        />
      </button>

      {/* Dropdown Menu */}
      {isOpen && (
        <div
          className={`absolute left-0 top-full mt-1 w-full min-w-[160px] max-h-56 overflow-y-auto rounded-lg border border-border/90 bg-surface-dark/95 backdrop-blur-md p-1 shadow-2xl z-50 animate-in fade-in zoom-in-95 duration-100 ${menuClassName}`}
          role="listbox"
        >
          {options.map((opt) => {
            const isSelected = opt.value === value;
            return (
              <button
                key={String(opt.value)}
                type="button"
                onClick={() => handleSelect(opt.value)}
                className={`w-full flex items-center justify-between gap-2 px-2 py-1.5 rounded-md text-left transition-colors ${
                  isSmall ? "text-xs" : "text-sm"
                } ${
                  isSelected
                    ? "bg-primary/15 text-primary font-medium"
                    : "text-text hover:bg-surface-hover hover:text-text"
                }`}
                title={opt.description || opt.label}
              >
                <div className="flex items-center gap-2 truncate min-w-0">
                  {opt.icon && <span className="shrink-0">{opt.icon}</span>}
                  <div className="truncate min-w-0">
                    <span className="block truncate">{opt.label}</span>
                    {opt.description && (
                      <span className="block text-[10px] text-text-muted truncate">
                        {opt.description}
                      </span>
                    )}
                  </div>
                </div>
                {isSelected && (
                  <Check size={isSmall ? 13 : 15} className="text-primary shrink-0 ml-1" />
                )}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}
