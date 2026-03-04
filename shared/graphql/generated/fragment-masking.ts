// Fragment masking utilities
export type FragmentType<T> = T;

export function useFragment<T>(fragment: T): T {
  return fragment;
}

export function makeFragmentData<T>(data: T): T {
  return data;
}