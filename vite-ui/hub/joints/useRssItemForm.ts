import { computed } from 'vue';
import { useQuery, useMutation } from '@vue/apollo-composable';
import { graphql } from '~apollo/generated'; // ✅ This should work now
import type {
    GetFormDataQuery,
    AddItemMutation,
    UpdateItemMutation,
    ItemInput
} from '~apollo/generated/graphql';

// ============================================
// Form Data Query Hook
// ============================================
export function useRssItemForm() {
    const GET_FORM_DATA = graphql(`
        query GetFormData {
            categories {
                categoryID
                categoryName
            }
            authors {
                buasriID
                firstName
                lastName
            }
        }
    `);

    const { result, loading, error } = useQuery(GET_FORM_DATA);

    return {
        categories: computed(() => result.value?.categories ?? []),
        authors: computed(() => result.value?.authors ?? []),
        loading,
        error,
    };
}

// ============================================
// Mutations Hook
// ============================================
export function useRssItemMutations() {
    // Create Item Mutation
    const ADD_ITEM = graphql(`
        mutation AddItem($input: AddItemInput!) {
            addItem(input: $input) {
                itemID
                title
                link
                description
                publishedDate
                category {
                    categoryID
                    categoryName
                }
                author {
                    buasriID
                    firstName
                    lastName
                }
            }
        }
    `);

    // Update Item Mutation
    const UPDATE_ITEM = graphql(`
        mutation UpdateItem($id: String!, $input: UpdateItemInput!) {
            updateItem(id: $id, input: $input) {
                itemID
                title
                link
                description
                publishedDate
                category {
                    categoryID
                    categoryName
                }
                author {
                    buasriID
                    firstName
                    lastName
                }
            }
        }
    `);

    const { mutate: addItem, loading: creating, onDone: onAddDone, onError: onAddError } = useMutation(ADD_ITEM);
    const { mutate: updateItem, loading: updating, onDone: onUpdateDone, onError: onUpdateError } = useMutation(UPDATE_ITEM);

    return {
        addItem,
        updateItem,
        creating,
        updating,
        onAddDone,
        onAddError,
        onUpdateDone,
        onUpdateError,
    };
}