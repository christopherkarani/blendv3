import { useCallback, useState } from 'react';

export const useLocalStorageState = (
  key: string,
  defaultState: string | undefined
): [string | undefined, (newState: string | undefined) => void] => {
  // Initialize state directly from localStorage or use defaultState
  const [state, setState] = useState<string | undefined>(() => {
    if (typeof window === 'undefined') return defaultState;

    try {
      const stored = localStorage.getItem(key);
      return stored ? JSON.parse(stored) : defaultState;
    } catch (e) {
      console.warn(`Error reading ${key} from localStorage:`, e);
      return defaultState;
    }
  });

  const setLocalStorageState = useCallback(
    (newState: string | undefined) => {
      const changed = state !== newState;
      if (!changed) {
        return;
      }
      setState(newState);
      if (newState === undefined) {
        localStorage.removeItem(key);
      } else {
        localStorage.setItem(key, JSON.stringify(newState));
      }
    },
    [state, key]
  );

  return [state, setLocalStorageState];
};
